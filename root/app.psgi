#!/usr/bin/env perl

use strict;
use warnings;

use Plack;
use Plack::Request;
use Plack::MIME;
use Plack::Builder;

use Path::Class ();
use JSON::XS    ();

use Perl::Critic;
use Git::Repository;

$ENV{CHECKOUT}       ||= '.';
$ENV{CRITIC_PROFILE} ||= './perlcritic.ini';

my $CHECKOUT = Path::Class::Dir->new( $ENV{CHECKOUT} );
my $JSON     = JSON::XS->new->utf8->pretty->canonical;
my $GIT_REPO = Git::Repository->new( work_tree => $CHECKOUT );

builder {

    mount '/fs/' => sub {
        my $r    = Plack::Request->new( $_[0] );
        my $path = $CHECKOUT->subdir( $r->path );

        return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
            unless -e $path;

        my $body;
        if ( -d $path ) {
            my @children = map +{
                path   => $_->basename,
                is_dir => (-d $_ ? 1 : 0)
            }, $path->children( no_hidden => 1 );

            if ( my $filter = $r->param('filter') ) {
                @children = grep $_->{path} =~ /$filter/, @children;
            }

            $body = {
                path     => $path->relative( $CHECKOUT )->stringify,
                is_dir   => 1,
                children => \@children
            };
        }
        else {
            $body = {
                path   => $path->relative( $CHECKOUT )->stringify,
                is_dir => 0,
            };
        }

        return [
            200,
            [ 'Content-Type' => 'application/json' ],
            [ $JSON->encode( $body ) ]
        ];
    };

    mount '/src/' => sub {
        my $r    = Plack::Request->new( $_[0] );
        my $path = $CHECKOUT->subdir( $r->path );

        return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
            unless -e $path;

        return [ 400, [], [ 'The path specified is a directory (' . $path->stringify . ")\n" ]]
            if -d $path;

        my $file = Path::Class::File->new( $path );
        my $mime = Plack::MIME->mime_type( $file->basename );

        return [
            200,
            [ 'Content-Type' => $mime ],
            [ $file->slurp ]
        ];
    };

    mount '/critique/' => sub {
        my $r    = Plack::Request->new( $_[0] );
        my $path = $CHECKOUT->subdir( $r->path );

        return [ 404, [], [ 'Could not find path (' . $path->stringify . ")\n" ]]
            unless -e $path;

        return [ 400, [], [ 'The path specified is a directory (' . $path->stringify . ")\n" ]]
            if -d $path;

        my $critic     = Perl::Critic->new( -profile => $ENV{CRITIC_PROFILE} );
        my @violations = $critic->critique( $path->stringify );
        my $statistics = $critic->statistics;

        return [
            200,
            [ 'Content-Type' => 'application/json' ],
            [
                $JSON->encode({
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
                })
            ]
        ];
    };

    mount '/git/' => builder {

        mount '/blame/' => sub {
            my $r    = Plack::Request->new( $_[0] );
            my $path = $CHECKOUT->subdir( $r->path );

            return [ 404, [], [ "Could not run <git blame> command, file not found ($path)\n" ]]
                unless -e $path;

            return [ 400, [], [ "The <git blame> command is not allowed without a valid file path (no directories)\n" ]]
                if -d $path;

            my $query = $r->query_parameters;

            my $line_range;
            if ( $query->{start} || $query->{end} ) {
                 $line_range = join ',' => (($query->{start} || 1), ($query->{end} || ()));
            }

            my $cmd = $GIT_REPO->command(
                blame => (
                    '-l',    # use the long version of the SHAs
                    ($line_range ? ('-L ' . $line_range) : ()),
                ) => $path
            );
            warn '[' . (join ' ' => $cmd->cmdline) . ']';
            my @all = $cmd->final_output;

            #return [ 200, [], [ join "\n" => @all ]];

            foreach my $i ( 1 .. scalar @all ) {

                #warn $all[ $i - 1 ];

                my ($sha, $info) = ($all[ $i - 1 ] =~ /([0-9a-f]{39,40})\s[A-Za-z0-9_\.\/]*\s*\((\w*[^\)]*)\)/);

                # first we ...
                # we match the line number
                my ($line_num) = ($info =~ /\s+(\d+)$/);
                # then strip off the line number
                $info =~ s/\s+\d+$//;
                # next we ...
                # extract the date by anchoring
                # from the rear of the string
                my ($date) = ($info =~ /([0-9-:+\s]*)$/);
                # then we ...
                # make sure to trim the leading
                # spaces that come along
                $date =~ s/^\s*//;
                # then we ...
                # use that same regexp to remove
                # the date so we are left with
                # only the author's name
                $info =~ s/([0-9-:+\s]*)$//;

                utf8::decode($info);

                $all[ $i - 1 ] = +{
                    sha      => $sha,
                    author   => $info,
                    date     => $date,
                    line_num => $line_num,
                };
            }

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [ $JSON->encode( \@all ) ]
            ];
        };

        mount '/log/' => sub {
            my $r    = Plack::Request->new( $_[0] );
            my $path = $CHECKOUT->subdir( $r->path );

            return [ 404, [], [ "Could not run <git log> command, file not found ($path)\n" ]]
                unless -e $path;

            return [ 400, [], [ "The <git log> command is not allowed without a valid file path (no directories)\n" ]]
                if -d $path;

            my $query = $r->query_parameters;

            my $cmd = $GIT_REPO->command(
                log => (
                    '--date=iso',
                    '--format=format:' . (
                        join '%n' => (
                            '%H',  # commit hash
                            '%an', # author name
                            '%ae', # author email
                            '%ad', # author date respecting --date
                            '%B',  # body
                            '%H',  # close
                        )
                    ),
                    # Support a few of the query limiting options
                    ($query->{max_count} ? ('--max-count=' . $query->{max_count}) : ()),
                    ($query->{skip}      ? ('--skip='      . $query->{skip}     ) : ()),
                    ($query->{since}     ? ('--since='     . $query->{since}    ) : ()),
                    ($query->{after}     ? ('--after='     . $query->{after}    ) : ()),
                    ($query->{until}     ? ('--until='     . $query->{until}    ) : ()),
                    ($query->{before}    ? ('--before='    . $query->{before}   ) : ()),
                    ($query->{author}    ? ('--author='    . $query->{author}   ) : ()),
                    ($query->{commiter}  ? ('--commiter='  . $query->{commiter} ) : ()),
                ) => $path
            );
            warn '[' . (join ' ' => $cmd->cmdline) . ']';
            my @all = $cmd->final_output;

            #return [ 200, [], [ join "\n" => @all ]];

            my @commits;
            while ( @all ) {
                my $sha          = shift @all;
                my $author_name  = shift @all;
                my $author_email = shift @all;
                my $author_date  = shift @all;
                # now collect the message
                my @body;
                push @body => shift @all
                    while @all && $all[0] ne $sha;
                shift @all; # discard the closing commit line

                utf8::decode($author_name);

                # and push onto commits
                push @commits => {
                    sha     => $sha,
                    author  => { name => $author_name, email => $author_email },
                    date    => ($author_date . ''),
                    message => (join "\n" => @body),
                };
            }

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [ $JSON->encode( \@commits ) ]
            ];
        };

        mount '/show/' => sub {
            my $r     = Plack::Request->new( $_[0] );
            my ($sha) = grep $_, split /\// => $r->path;

            return [ 400, [], [ "The <git show> command is not allowed without a sha to view\n" ]]
                unless $sha;

            my $cmd = $GIT_REPO->command(
                show => (
                    '--date=iso',
                    '--format=format:' . (
                        join '%n' => (
                            '%H',  # commit hash
                            '%an', # author name
                            '%ae', # author email
                            '%ad', # author date respecting --date
                            '%B',  # body
                            '%H',  # close
                        )
                    ),
                    '--numstat',
                    '--summary',
                ) => $sha
            );
            warn '[' . (join ' ' => $cmd->cmdline) . ']';
            my @all = $cmd->final_output;

            #return [ 200, [], [ join "\n" => @all ]];

            die 'This should never happen, looking for (' . $sha . ') but found (' . $all[0] . ") in:\n" . (join "\n" => @all)
                if $all[0] ne $sha;

            shift @all; # discard this line, we already have the sha
            my $author_name  = shift @all;
            my $author_email = shift @all;
            my $author_date  = shift @all;
            # now collect the message
            my @body;
            push @body => shift @all
                while @all && $all[0] ne $sha;
            shift @all; # discard the closing commit line

            utf8::decode($author_name);

            # collect all the file details ...
            my %files;
            while ( @all && $all[0] =~ /^\d+/ ) {
                my $line = shift @all;
                my ($added, $removed, $path) = split /\s+/ => $line;
                $files{ $path } = {
                    path    => $path,
                    added   => $added,
                    removed => $removed
                };
            }

            while ( @all && $all[0] =~ /^\s[create|delete]/ ) {
                my $line = shift @all;
                #warn $line;
                my ($action, $path) = ($line =~ /^\s(.*) mode \d+ (.*)/);
                #warn join ", " => $action, $path;
                $files{ $path }->{action} = $action;
            }

            shift @all while @all && $all[0] =~ /^\s*$/; # discard the empty newlines

            return [
                200,
                [ 'Content-Type' => 'application/json' ],
                [
                    $JSON->encode({
                        sha     => $sha,
                        author  => { name => $author_name, email => $author_email },
                        date    => ($author_date . ''),
                        message => (join "\n" => @body),
                        files   => [ values %files ],
                    })
                ]
            ];
        };

        mount '/' => sub {
            return [
                400,
                [],
                [ 'Unsupported git command (' . $_[0]->{PATH_INFO} . ') supported commands include ( /git/show/:sha, /git/log/:path, /git/blame/:path )' ]
            ];
        };
    };

    mount '/' => sub {
        return [ 404, [], []];
    };
};


