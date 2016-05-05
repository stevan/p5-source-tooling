package Code::Tooling::Perl;

use strict;
use warnings;

use Perl::Critic;

sub new {
    my ($class, %args) = @_;
    return bless { %args } => $class;
}

# ...

sub critique {
    my ($self, $path, $query) = @_;

    my $critic     = Perl::Critic->new( -profile => $self->{perlcritic_profile} );
    my @violations = $critic->critique( $path->stringify );
    my $statistics = $critic->statistics;

    return {
        statistics => {
            modules    => $statistics->modules,
            subs       => $statistics->subs,
            statements => $statistics->statements,
            violations => {
                total => $statistics->total_violations,
            },
            lines      => {
                total    => $statistics->lines,
                blank    => $statistics->lines_of_blank,
                comments => $statistics->lines_of_comment,
                data     => $statistics->lines_of_data,
                perl     => $statistics->lines_of_perl,
                pod      => $statistics->lines_of_pod,
            },
        },
        violations => [
            map +{
                severity    => $_->severity,
                description => $_->description,
                policy      => $_->policy,
                source => {
                    code     => $_->source,
                    location => {
                        line   => $_->line_number,
                        column => $_->column_number,
                    },
                },
            }, @violations
        ]
    }
}

1;

__END__
