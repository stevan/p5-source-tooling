#!perl

use strict;
use warnings;

use Path::Class  ();
use JSON::XS     ();
use Getopt::Long ();
use PPI;

our $DEBUG = 0;

sub main {

    my ($root, $exclude);
    Getopt::Long::GetOptions(
        'root=s'    => \$root,
        'exclude=s' => \$exclude,
        'verbose'   => \$DEBUG,
    );

    (-e $root && -d $root)
        || die 'You must specifiy a valid root directory';

    my @modules;
    visit(
        Path::Class::Dir->new( $root ), (
            exclude => $exclude,
            visitor => \&extract_module_version_information,
            acc     => \@modules,
        )
    );

    my $json = JSON::XS->new->utf8->pretty->canonical;
    print $json->encode( \@modules );
}

main && exit;

# subs ....

sub visit {
    my ($e, %args) = @_;

    if ( -f $e ) {
        $args{visitor}->( $e, $args{acc} );
    }
    else {
        if ( my $exclude = $args{exclude} ) {
            return if $e->basename =~ /$exclude/;
        }
        map visit( $_, %args ), $e->children( no_hidden => 1 );
    }

    return;
}

sub extract_module_version_information {
    my ($e, $acc) = @_;

    warn "Looking at '$e'" if $DEBUG;

    my $doc = PPI::Document->new( $e->stringify );

    my $current;
    $doc->find(sub {
        my ($root, $node) = @_;

        # if we have a current namespace, descend to find version ...
        if ( $current ) {

            # Must be a quote or number
            $node->isa('PPI::Token::Quote')          or
            $node->isa('PPI::Token::Number')         or return '';

            # To the right is a statement terminator or nothing
            my $t = $node->snext_sibling;
            if ( $t ) {
                $t->isa('PPI::Token::Structure') or return '';
                $t->content eq ';'               or return '';
            }

            # To the left is an equals sign
            my $eq = $node->sprevious_sibling        or return '';
            $eq->isa('PPI::Token::Operator')         or return '';
            $eq->content eq '='                      or return '';

            # To the left is a $VERSION symbol
            my $v = $eq->sprevious_sibling           or return '';
            $v->isa('PPI::Token::Symbol')            or return '';
            $v->content =~ m/^\$(?:\w+::)*VERSION$/  or return '';

            # To the left is either nothing or "our"
            my $o = $v->sprevious_sibling;
            if ( $o ) {
                $o->content eq 'our'             or return '';
                $o->sprevious_sibling           and return '';
            }

            warn "Found possible version in '$current' in '$e'" if $DEBUG;

            my $version;
            if ( $node->isa('PPI::Token::Quote') ) {
                if ( $node->can('literal') ) {
                    $version = $node->literal;
                } else {
                    $version = $node->string;
                }
            } elsif ( $node->isa('PPI::Token::Number') ) {
                if ( $node->can('literal') ) {
                    $version = $node->literal;
                } else {
                    $version = $node->content;
                }
            } else {
                die 'Unsupported object ' . ref($node);
            }

            warn "Found version '$version' in '$current' in '$e'" if $DEBUG;

            # we've found it!!!!
            push @$acc => {
                namespace => $current,
                path      => $e->stringify,
                version   => $version,
            };

            undef $current;
        }
        else {
            # otherwise wait for next package ...
            return 0 unless $node->isa('PPI::Statement::Package');
            $current = $node->namespace;

            warn "Found package '$current' in '$e'" if $DEBUG;
        }

        return;
    });
}

1;
