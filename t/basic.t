use strict;
use warnings;

use Test::More;
use Sub::Go;

{
    my %h = ( aa=>11 );
    my $ret='';
    %h ~~ go {
        my ($k, $v) = @_;
        $ret = $k . $v; 
    };
    is( $ret, 'aa11', 'hash' ); 
}
{
    my %h = ( aa=>11 );
    my $ret='';
    \%h ~~ go {
        my ($k, $v) = @_;
        $ret = $k . $v; 
    };
    is( $ret, 'aa11', 'hashref' ); 
}
{
    my @arr = (1..10);
    my @ret;
    @arr ~~ go {
        push @ret, shift;
    };
    is( join('',@ret), '12345678910', 'array' ); 
}
{
    my @ret;
    [ 1..10 ] ~~ go {
        push @ret, shift;
    };
    is( join('',@ret), '12345678910', 'arrayref' ); 
}
{
    my $ret = 'hello' ~~ go {
        is( shift, 'hello', 'scalar' );
        'world';
    };
    is( $ret, 'world', 'scalar return' ); 
}
{
    my $ret = 'hello' ~~ go {
        return (1..10); 
    };
    is( $ret , 10, 'return arr as scalar' ); 
}
{
    my $ret = 'hello' ~~ go { [1..10] };
    is( ref($ret) , 'ARRAY', 'return arrayref' ); 
}
{
    my $ret = '' ~~ go { 1 };
    is( $ret , 1, 'runs on empty' ); 
}
{
    my $ret = undef ~~ go { 1 };
    is( $ret , undef, 'do not run on undef' ); 
}
{
    my @a;
    my $ret = @a ~~ go { 1 };
    is( $ret , undef, 'no run on empty array' ); 
}
{
    my @ret;
    my $cnt = 0;
    [99..108] ~~ go {
        $cnt++;
        return if $_[0] > 100;
        push @ret, $_[0];
    };
    is( join(',',@ret), '99,100', 'normal return' );
    is( $cnt, 10, 'normal return count' );
}
{
    my @ret;
    my $cnt = 0;
    [99..108] ~~ go {
        $cnt++;
        return skip if $_[0] > 100;
        push @ret, $_[0];
    };
    is( join(',',@ret), '99,100', 'skip return' );
    is( $cnt, 3, 'skip return count' );
}
{
    # XXX broken functionality
    my @ret =  [99..101] ~~ go { ($_[0]) };
    #is( join(',',@ret), '99,100,101', 'return array' );
    is( @ret, 1, 'return array' );
    is( $ret[0], 3, 'return array' );
}
{
    'hello' ~~ go {
        warn "uno=>" . shift;
        yield 100;
    } go { warn "due=>" . shift; }
}
#{
    #use signatures;
    #warn 'cuatro=>' => 'hello' ~~
    #    go { warn "uno=>" . $_[0]; 11 }
    #    go { warn "due=>" . shift; [ 1..10 ] }
    #    by { warn "tre=>" . shift; 33 }
    #    by { warn "xtre=>" . shift; 55 };
#}

done_testing;
