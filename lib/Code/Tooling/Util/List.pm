package Code::Tooling::Util::List;

use v5.22;
use warnings;

use experimental qw[
    signatures
    postderef
];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';
our $DEBUG     = 0;

our @EXPORT_OK = qw[
    &split_array_equally
];

sub split_array_equally ($array, $cnt_groups) {
    return undef if( !defined($array) || ref $array ne 'ARRAY');
    return undef if( !defined($cnt_groups) || $cnt_groups !~ /^\d+$/ || $cnt_groups<1 );

    my $array_groups = [];
    my @array_copy = $array->@*;
    my $min_seg_size = int( (@array_copy) / $cnt_groups );
    my $cnt_large_segs = (@array_copy) % $cnt_groups;
    push $array_groups->@*, [ splice @array_copy, 0, ($min_seg_size+1) ] while ( $cnt_large_segs-- > 0);
    push $array_groups->@*, [ splice @array_copy, 0, $min_seg_size ] while @array_copy;
    return $array_groups;
}

1;

__END__
