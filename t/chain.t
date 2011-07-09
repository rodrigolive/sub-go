use strict;
use warnings;

use Test::More;
use Sub::Go;

{
    my $cnt;
    [1..3] ~~
        go {
            sub { yield [100] }->();
            99;
        }
        go {
           $cnt += shift->[0] ;
        };
    is $cnt, 300, 'yield';
}

{
    my $uno=0;
    my $due=0;
    [1..3] ~~
        go {
            ++$uno;
            return skip if $uno > 1;
        }
        go {
           $due++;
        };
    is $uno, 2, 'skip uno';
    is $due, 1, 'skip due';
}

{
    my $uno=0;
    my $due=0;
    [1..3] ~~
        go {
            ++$uno;
            return stop if $uno > 1;
        }
        go {
           $due++;
        };
    is $uno, 2, 'stop uno';
    is $due, 0, 'stop due';
}

done_testing
