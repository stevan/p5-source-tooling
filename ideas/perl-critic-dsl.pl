#!perl -w

use v5.20;

use strict;
use warnings;

use Carp 'confess';

use PPI;
use PPI::Document;
use PPI::Dumper;

## --------------------------------------------------------

sub ignore (;$) {
    my ($cont) = @_;
    $cont //= sub { 1 };
    return sub {
        return $cont->( @_ );
    }
}

sub find_type ($;$) {
    my ($type, $cont) = @_;
    $cont //= sub { 1 };
    return sub {
        my ($root, $node) = @_;
        return $cont->( $root, $node ) if $node->isa($type);
        return;
    }
}

sub is_false ($;$) {
    my ($method, $cont) = @_;
    $cont //= sub { 1 };
    return sub {
        my ($root, $node) = @_;
        return $cont->( $root, $node )
            if $node->can( $method ) && not $node->$method();
        return;
    }
}

sub is_true ($;$) {
    my ($method, $cont) = @_;
    $cont //= sub { 1 };
    return sub {
        my ($root, $node) = @_;
        return $cont->( $root, $node )
            if $node->can( $method ) && $node->$method();
        return;
    }
}

sub descend ($$;$) {
    my ($method, $tester, $cont) = @_;
    $cont //= sub { 1 };
    return sub {
        my ($root, $node) = @_;

        my $m = $node->can( $method );

        defined $m
            or confess 'Could not find (' . $method . ') to match against';

        my $to_match = $node->$m();

        defined $to_match
            or confess 'The method (' . $method . ') did not return value to match against';

        my $results = $to_match->find( $tester );

        return $cont->( $root, $node ) if $results;
        return;
    };
}

sub content ($;$) {
    my ($value, $cont) = @_;
    $cont //= sub { 1 };
    return sub {
        my ($root, $node) = @_;
        return $cont->( $root, $node )
            if $node->can('content') && $node->content.'' eq $value.'';
        return;
    }
}

sub children_are ($;$) {
    my ($testers, $cont) = @_;

    ref $testers eq 'ARRAY'
        or confess 'The first argument to children_are must be an ARRAY ref';

    $cont //= sub { 1 };
    return sub {
        my ($root, $node) = @_;

        my @children     = $node->schildren;
        my $num_children = scalar @children;

        ($num_children == (scalar @$testers))
            or confess 'The number of testers much match the number of children '
                     . '(children: ' . $num_children . ')==(testers: ' . (scalar @$testers) . ')';

        foreach my $i ( 0 .. ($num_children - 1)) {
            my $child  = $children[ $i ];
            my $tester = $testers->[ $i ];

            $tester->( $node, $child )
                // return;
        }

        return $cont->( $root, $node );
    }
}

## --------------------------------------------------------

my $source = q[
    sub match {
        my ($x) = shift;

        return $x + 1;
    }

    sub not_match {
        my $x = shift;

        return $x * 1;
    }

    sub not_match_again {
        my ($x, $y) = (shift, 10);

        return $x * 1;
    }

    sub no_args {
        my $x;
    }

    sub no_args_w_init {
        my $x = 10;
    }

    sub no_args_multi {
        my ($x, $y);
    }

    sub no_args_multi_init {
        my ($x, $y) = (10, 20);
    }

    sub forward_decl;
];

my $matcher = find_type 'PPI::Statement::Sub',
    is_false 'forward',
    is_false 'reserved',
    descend 'block',
        find_type 'PPI::Statement::Variable',
            children_are [
                 content('my'),
                 find_type('PPI::Structure::List'),
                 find_type('PPI::Token::Operator', content('=')),
                 find_type('PPI::Token::Word',     content('shift')),
                 content(';'),
            ]
    ;

## --------------------------------------------------------

if ( my $matches = PPI::Document->new(\$source)->find($matcher) ) {
    warn "Got " . (scalar @$matches) . " matches";
    (say("... START ..."),
        PPI::Dumper->new($_)->print,
            say("... END ..."))
                foreach @$matches;
}
else {
    warn "Got nothing";
}

1;

__END__
