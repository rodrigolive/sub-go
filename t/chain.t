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
{
    my $x = 100;
    my $y = $x ~~ go { $_ * 2 } go { $_ * 3 } go { 4 * $_ };
    is $x, 100, 'not changed';
    is $y, 2400, 'triple chain';
}
{
    my @arr = (1..3);
    my @out;
    @arr ~~ go { 2 * $_ }
        go { $_ += 100; qw/a b c/ }
        go { shift() . 'x' } \@out;  
    warn @out;
}

#[1..10] ~~ go { warn "A=$_"; };
#warn join ',' => bug { warn ">>>>$_" } [1..10];

done_testing
