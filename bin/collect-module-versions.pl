#!perl

use strict;
use warnings;

use Path::Class  ();
use Getopt::Long ();
use Data::Dumper ();
use PPI;

use Code::Tooling::Util::JSON qw[ encode ];

our $DEBUG = 0;
our $ROOT;

sub main {

    my ($exclude, $include);
    Getopt::Long::GetOptions(
        'root=s'    => \$ROOT,
        'exclude=s' => \$exclude,
        'include=s' => \$include,
        'verbose'   => \$DEBUG,
    );

    (-e $ROOT && -d $ROOT)
        || die 'You must specifiy a valid root directory';

    $ROOT = Path::Class::Dir->new( $ROOT );

    (defined $include && defined $exclude)
        && die 'You can not have both include and exclude patterns';

    my @modules;
    visit(
        $ROOT, (
            ($exclude ? (exclude => $exclude) : ()),
            ($include ? (include => $include) : ()),
            visitor => \&extract_module_version_information,
            acc     => \@modules,
        )
    );

    print encode( \@modules );
}

main && exit;

# subs ....

sub visit {
    my ($e, %args) = @_;

    if ( -f $e ) {
        $args{visitor}->( $e, $args{acc} )
            if $e->basename =~ /\.p[ml]/i;
    }
    else {
        warn "Got e($e) and ROOT($ROOT)" if $DEBUG;

        my @children = $e->children( no_hidden => 1 );
        warn "ROOT: GOT children: " . Data::Dumper::Dumper([ map $_->relative( $ROOT )->stringify, @children ]) if $DEBUG;

        if ( my $exclude = $args{exclude} ) {
            warn "ROOT: Looking to exclude '$exclude' ... got: " . $e->basename if $DEBUG;
            @children = grep $_->relative( $ROOT )->stringify !~ /$exclude/, @children;
        }

        if ( my $include = $args{include} ) {
            warn "ROOT: Looking to include '$include' ... got: " . $e->basename if $DEBUG;
            @children = grep $_->relative( $ROOT )->stringify =~ /$include/, @children;
        }

        warn "ROOT: Getting ready to run with children: " . Data::Dumper::Dumper([ map $_->relative( $ROOT )->stringify, @children ]) if $DEBUG;
        map visit( $_, %args ), @children;
    }

    return;
}

sub extract_module_version_information {
    my ($e, $acc) = @_;

    warn "Looking at '$e'" if $DEBUG;

    my $doc = PPI::Document->new( $e->stringify );

    (defined $doc)
        || die 'Could not load document: ' . $e->stringify;

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
            $acc->[-1]->{version} = $version;

            undef $current;
        }
        else {
            # otherwise wait for next package ...
            return 0 unless $node->isa('PPI::Statement::Package');
            $current = {
                namespace => $node->namespace,
                line_num  => $node->line_number,
                path      => $e->relative( $ROOT )->stringify,
            };

            push @$acc => $current;

            warn "Found package '$current' in '$e'" if $DEBUG;
        }

        return;
    });
}

1;
