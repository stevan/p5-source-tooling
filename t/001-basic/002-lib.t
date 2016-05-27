#!/usr/bin/env perl

use v5.22;
use warnings;

use lib 'lib';

use Test::More;
use Test::Fatal;

use experimental 'postderef';

use Importer 'Code::Tooling::Util::Transform'       => qw[ split_array_equally ];

subtest 'split_array_equally_good_tests' => sub  {
	my $test_cases = [
		{
			name				=> 'normal_test_1',
			input 				=> {
					array 		=> [1,2,3,4],
					group_cnt 	=> 3,
			},
			expected_output 	=> [ [1,2],[3],[4], ],
		},
		{
			name				=> 'normal_test_2',
			input 				=> {
					array 		=> [1,2,3,4,5],
					group_cnt 	=> 3,
			},
			expected_output 	=> [ [1,2],[3,4],[5], ],
		},
		{
			name				=> 'normal_test_3',
			input 				=> {
					array 		=> [1,2,3,4,5,6],
					group_cnt 	=> 3,
			},
			expected_output 	=> [ [1,2],[3,4],[5,6], ],
		},
		{
			name				=> 'normal_test_4',
			input 				=> {
					array 		=> [1,2,3,4,5,6,7],
					group_cnt 	=> 3,
			},
			expected_output 	=> [ [1,2,3],[4,5],[6,7], ],
		},
		{
			name				=> 'normal_test_5_one_bigger_bucket',
			input 				=> {
					array 		=> [(1..100)],
					group_cnt 	=> 3,
			},
			expected_output 	=> [ [ (1..34) ],[(35..67)],[(68..100)], ],
		},
		{
			name				=> 'normal_test_6_equal_bucket_size',
			input 				=> {
					array 		=> [(1..100)],
					group_cnt 	=> 2,
			},
			expected_output 	=> [ [ (1..50) ],[(51..100)] ],
		},
		{
			name				=> 'normal_test_7_moresegments_than_possible',
			input 				=> {
					array 		=> [(1..4)],
					group_cnt 	=> 10,
			},
			expected_output 	=> [ [ 1 ],[ 2 ],[ 3 ],[ 4 ], ],
		},
		{
			name				=> 'normal_test_8_empty_array',
			input 				=> {
					array 		=> [],
					group_cnt 	=> 5,
			},
			expected_output 	=> [ ],
		},
    ];

    for my $test ($test_cases->@*) {
    	is_deeply( split_array_equally($test->{input}->{array},$test->{input}->{group_cnt}), $test->{expected_output} , $test->{name} );
    }
};

subtest 'split_array_equally_exception_tests' => sub  {
	my $test_cases = [
		{
			name				=> 'exception_test_1',
			input 				=> {
					array 		=> [1,2,3,4],
					group_cnt 	=> undef,
 			},
			expected_exception 	=> 'invalid second arg, expected positive integer',
		},
		{
			name				=> 'exception_test_2',
			input 				=> {
					array 		=> [1,2,3,4,5],
					group_cnt 	=> {},
 			},
			expected_exception 	=> 'invalid second arg, expected positive integer',
		},
		{
			name				=> 'exception_test_3',
			input 				=> {
					array 		=> [1,2,3,4,5,6],
					group_cnt 	=> 'pizza',
 			},
			expected_exception 	=> 'invalid second arg, expected positive integer',
		},
		{
			name				=> 'exception_test_4',
			input 				=> {
					array 		=> [1,2,3,4,5,6,7],
					group_cnt 	=> {a=>'a','d'=>4},
 			},
			expected_exception 	=> 'invalid second arg, expected positive integer',
		},
		{
			name				=> 'exception_test_5',
			input 				=> {
					array 		=> undef,
					group_cnt 	=> 3,
 			},
			expected_exception 	=>  'invalid first arg, expected array ref',
		},
		{
			name				=> 'exception_test_6',
			input 				=> {
					array 		=> undef,
					group_cnt 	=> undef,
 			},
			expected_exception 	=>  'invalid first arg, expected array ref',
		},
		{
			name				=> 'exception_test_7',
			input 				=> {
					array 		=> {some=>'s'},
					group_cnt 	=> 2,
		},
			expected_exception 	=>  'invalid first arg, expected array ref',
		},
    ];

    for my $test ($test_cases->@*) {
    	#dies_ok { split_array_equally($test->{input}->{array},$test->{input}->{group_cnt}) } $test->{expected_exception} ;
		like( exception{ split_array_equally($test->{input}->{array},$test->{input}->{group_cnt}) }, qr/$test->{expected_exception}/, "got proper exception:$test->{expected_exception}" );
    }
};



done_testing;