package Code::Tooling::Perl;

use v5.22;
use warnings;
use experimental qw[
    signatures
    lexical_subs
];

use Perl::Critic     ();
use version          ();
use Module::CoreList ();
use Module::Runtime  ();

use Code::Tooling::Perl::MetaCPAN;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

sub new ($class, %args) {

    $args{perl_version} = version->parse( $args{perl_version} )->numify
        if $args{perl_version};

    return bless {
        _metacpan => Code::Tooling::Perl::MetaCPAN->new( @{ $args{metacpan_args} || [] } ),
        # hash slices FTW
        %args{qw[
            perlcritic_profile
            perl_version
        ]},
    } => $class;
}

# metacpan

sub metacpan { $_[0]->{_metacpan} }

# general module stuff

sub is_core_module ($self, $module) {
    !! Module::CoreList::is_core( $module, undef, $self->{perl_version} || () );
}

sub is_module_deprecated ($self, $module) {
    !! Module::CoreList::is_deprecated( $module, $self->{perl_version} || () );
}

sub classify_modules ($self, @modules) {
    return [
        map +{
            is_core => ($self->is_core_module( $_ ) ? 1 : 0),
            name    => $_,
            path    => Module::Runtime::module_notional_filename( $_ ),
        }, @modules
    ];
}

## PPI related stuff

sub extract_module_info ($self, $source) {

    my $doc = PPI::Document->new( $source->stringify );

    (defined $doc)
        || die 'Could not load document: ' . $source->stringify;

    # TODO:
    # This whole method is in desperate need of a re-write.
    # It was copy/pasted togehter from a couple of sources
    # and I never really took the time to understand it. I
    # am now convinced that it is the wrong approach, but
    # until I write an actual test suite, I won't be sure.
    # - SL

    my sub find_variable ($current, $node, $var_name) {
        # Must be a quote or number
        $node->isa('PPI::Token::Quote')          or
        $node->isa('PPI::Token::Number')         or return;

        # To the right is a statement terminator or nothing
        my $t = $node->snext_sibling;
        if ( $t ) {
            $t->isa('PPI::Token::Structure') or return;
            $t->content eq ';'               or return;
        }

        # To the left is an equals sign
        my $eq = $node->sprevious_sibling        or return;
        $eq->isa('PPI::Token::Operator')         or return;
        $eq->content eq '='                      or return;

        # To the left is a $var_name symbol (VERSION, AUTHORITY, etc)
        my $v = $eq->sprevious_sibling           or return;
        $v->isa('PPI::Token::Symbol')            or return;
        $v->content =~ m/^\$(?:\w+::)*${var_name}$/  or return;

        # To the left is either nothing or "our"
        my $o = $v->sprevious_sibling;
        if ( $o ) {
            $o->content eq 'our'             or return;
            $o->sprevious_sibling           and return;
        }

        warn "Found possible $var_name in '$current->{namespace}' in '$source'" if $DEBUG;

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
            die 'Unsupported object ' . ref($node);
        }

        warn "Found version '$value' in '$current->{namespace}' in '$source'" if $DEBUG;

        return $value;
    }

    my ($current, @modules);
    $doc->find(sub {
        my ($root, $node) = @_;

        # if we have a current namespace, descend to find version ...
        if ( $current ) {

            $modules[-1]->{VERSION}   ||= find_variable( $current, $node, 'VERSION' );
            $modules[-1]->{AUTHORITY} ||= find_variable( $current, $node, 'AUTHORITY' );

            return '' unless $modules[-1]->{VERSION} && $modules[-1]->{AUTHORITY};

            undef $current;
        }
        else {
            # otherwise wait for next package ...
            return 0 unless $node->isa('PPI::Statement::Package');
            $current = {
                namespace => $node->namespace,
                line_num  => $node->line_number,
                path      => $source->stringify,
                VERSION   => undef,
                AUTHORITY => undef,
            };

            push @modules => $current;

            warn "Found package '$current->{namespace}' in '$source'" if $DEBUG;
        }

        return;
    });

    return \@modules;
}

# Perl::Critic oriented stuff

sub critique ($self, $path, $query) {

    ($self->{perlcritic_profile} && -f $self->{perlcritic_profile})
        || die 'The Perl::Critic profile must be set to a valid file path before running the `critique` method';

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
