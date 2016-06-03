package Source::Tooling::Util::PPI;

use v5.22;
use warnings;
use experimental 'signatures';

use PPI;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

our @EXPORT_OK = qw[
    &extract_symbols_and_values_from_variable
];

sub extract_symbols_and_values_from_variable ($node) {

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
