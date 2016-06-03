package Source::Tooling::Util::PPI;

use v5.22;
use warnings;
use experimental 'signatures';

use PPI;

use Scalar::Util ();

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

our @EXPORT_OK = qw[
    &extract_symbols_and_values_from_variable
    &extract_symbol_and_value_from_statement
    &extract_sensible_value_from_token
];

sub extract_sensible_value_from_token ($node) {

    (Scalar::Util::blessed( $node ) && $node->isa('PPI::Token'))
        || die 'You must pass a valid `PPI::Token` instance';

    my $value;
    if ( $node->isa('PPI::Token::Quote') ) {
        if ( $node->can('literal') ) {
            $value = $node->literal;
        } else {
            $value = $node->string;
        }
    } elsif ( $node->isa('PPI::Token::Number') ) {
        if ( $node->can('literal') ) {
            $value = $node->literal;
        } else {
            $value = $node->content;
        }
    } else {
        $value = $node->content;
    }
    return $value;
}

sub extract_symbol_and_value_from_statement ($node) {

    (Scalar::Util::blessed( $node ) && $node->isa('PPI::Statement'))
        || die 'You must pass a valid `PPI::Statement` instance';

    my $symbol = $node->schild(0);

    # ignore this statement unless ...
    return unless Scalar::Util::blessed($symbol)        # we find something
               && $symbol->isa('PPI::Token::Symbol')    # and it is a symbol
               && index( $symbol->content, '::' ) >= 0; # and it has :: in it

    my $op = $symbol->snext_sibling;

    # ignore this statement unless ...
    return unless Scalar::Util::blessed($op)        # we find something
               && $op->isa('PPI::Token::Operator')  # and it is an operator
               && $op->content eq '=';              # and it is assignment

    return $symbol, $op->snext_sibling;
}

sub extract_symbols_and_values_from_variable ($node) {

    (Scalar::Util::blessed( $node ) && $node->isa('PPI::Statement::Variable'))
        || die 'You must pass a valid `PPI::Statement::Variable` instance';

    my (@symbols, @values);

    if ( @symbols = $node->symbols ) {

        #warn ('=' x 80);
        #warn $node->content;
        #warn ('=' x 80);

        if ( my $last = $node->last_token ) {
            # NOTE:
            # this might not be right, we might not
            # always have a semicolon here
            # - SL
            if ($last->isa('PPI::Token::Structure') && $last->content eq ';') {

                my $possible_value = $last->sprevious_sibling;

                if ( $possible_value->isa('PPI::Structure::List') ) {
                    # NOTE:
                    # I might be assuming too much about the
                    # fact children will return a single expression
                    # object, so might want to rethink this.
                    # - SL
                    if ( my @children = ($possible_value->children)[0]->schildren ) {

                        # warn "GOT A LIST, looking for a match";
                        # warn join "\n" => map { join ' => ' => ref($_), Scalar::Util::refaddr($_) } $symbols[-1], $children[-1];
                        # warn ('-' x 80);
                        # warn Data::Dumper::Dumper( $symbols[-1] );
                        # warn ('-' x 80);
                        # warn Data::Dumper::Dumper( $children[-1] );

                        if ( $children[-1] ne $symbols[-1] ) {
                            push @values => grep !$_->isa('PPI::Token::Operator'), @children;
                        }
                    }
                }
                elsif ( $possible_value->isa('PPI::Token::Symbol') ) {

                    # warn "GOT A SINGLE, looking for a match";
                    # warn join "\n" => map { join ' => ' => ref($_), Scalar::Util::refaddr($_) } $symbols[-1], $possible_value;
                    # warn ('-' x 80);
                    # warn Data::Dumper::Dumper( $symbols[-1] );
                    # warn ('-' x 80);
                    # warn Data::Dumper::Dumper( $possible_value );

                    if ( $possible_value ne $symbols[-1] ) {
                        push @values => $possible_value;
                    }
                }
                else {
                    # no idea what it is, but just take it
                    push @values => $possible_value;
                }
            }
        }
    }

    return \@symbols, \@values;
}

1;

__END__
