package code::tooling::git;

use strict;
use warnings;

sub log {
    my ($repo, $path, $query) = @_;

    my $cmd = $repo->command(
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
    warn '[' . (join ' ' => $cmd->cmdline) . ']' if $query->{debug};
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

    return \@commits;
}

1;

__END__
