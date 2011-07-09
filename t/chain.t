use strict;
use warnings;

use Test::More;
use Sub::Go;
use Method::Signatures;

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
            return get_out if $uno > 1;
        }
        go {
           $due++;
        };
    is $uno, 2, 'get_out uno';
    is $due, 1, 'get_out due';
}

{
    my $uno=0;
    my $due=0;
    [1..3] ~~
        go {
            ++$uno;
            return Sub::Go::get_out_all if $uno > 1;
        }
        go {
           $due++;
        };
    is $uno, 2, 'get_out_all uno';
    is $due, 0, 'get_out_all due';
}

done_testing
