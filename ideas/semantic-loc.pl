#!perl

use v5.20;
use warnings;
use Path::Class qw[ file ];

use PPI;
use PPI::Document;
use PPI::Dumper;

use Test::More;

my $FILE = file $ARGV[0];

die "Could not find the file: $FILE"  unless -e $FILE && -f $FILE;

my $doc = PPI::Document->new( $FILE->stringify )
    or die 'could not parse ' . $FILE . ' because ' . PPI::Document->errstr;

#PPI::Dumper->new( $doc )->print;

my $sloc = 0;

my $statements = $doc->find(sub {
    my ($root, $current) = @_;
    # nothing useful in __END__ or __DATA__ blocks for us
    return undef
        if $current->isa('PPI::Statement::End')
        || $current->isa('PPI::Statement::Data')
        || $current->isa('PPI::Statement::Null');

    # if this is a sub, then ...
    if ($current->isa('PPI::Statement::Sub')) {
        # if it is not a BEGIN/INIT/CHECK/UNITCHECK/END,
        # then do not descend, we will check them later
        return undef if not $current->isa('PPI::Statement::Scheduled');
    }
    # otherwise, check all statements
    return !!$current->isa('PPI::Statement');
});

if ( $statements ) {
    $sloc += scalar @$statements;
}

warn "... found $sloc outside of subroutines";

my $subs = $doc->find(sub {
    my ($root, $current) = @_;
    return $current->isa('PPI::Statement::Sub') && !$current->isa('PPI::Statement::Scheduled');
});

my %subs;
if ( $subs ) {
    foreach my $sub ( @$subs ) {
        $sloc++; # each sub defintion is 1 SLOC + Body SLOC

        my $stmts = $sub->block->find(sub {
            my ($root, $current) = @_;
            return !!$current->isa('PPI::Statement::Variable') if $current->isa('PPI::Statement::Expression');
            return !!$current->isa('PPI::Statement');
        });

        if ( $stmts ) {
            $subs{ $sub->name } = $stmts;

            $sloc += scalar @$stmts;

            my $else_blocks = $sub->block->find(sub {
                my ($root, $current) = @_;
                return (
                    $current->isa('PPI::Token::Word')
                        &&
                    (
                        $current->literal eq 'else'
                            ||
                        $current->literal eq 'elsif'
                    )
                )
            });

            my $maybe_more = '';

            if ( $else_blocks ) {
                $sloc += scalar @$else_blocks;
                $maybe_more = " (with " . (scalar @$else_blocks) . " else blocks)";
            }

            warn "... found " . (scalar @$stmts) . " statements${maybe_more} in " . $sub->name;
        }
        else {
            warn "... found 0 statements in " . $sub->name;
        }
    }
}


if ( $ENV{DEBUG} ) {
    my $x = 1;
    foreach my $stmt ( @$statements ) {
        say($x++, ' ', '-' x 80);
        print $stmt->content, "\n";
        #PPI::Dumper->new( $stmt )->print;
    }

    if ( %subs ) {
        foreach my $sub ( @$subs ) {
            say('=' x 80);
            say $sub->name;
            say('=' x 80);
            $x = 1;
            foreach my $stmt ( @{ $subs{ $sub->name } } ) {
                say($x++, ' ', '-' x 80);
                print $stmt->content, "\n";
                #PPI::Dumper->new( $stmt )->print;
            }
        }
    }
}

my $loc = 0;
$doc->prune('PPI::Statement::End');
$doc->prune('PPI::Statement::Data');
$doc->prune('PPI::Statement::Null');
$doc->prune('PPI::Token::Comment');
$loc = scalar grep { $_ } split /\n/ => $doc->content;

warn "Got a total of $sloc SLOC";
warn "Got a total of $loc LOC";

done_testing;
