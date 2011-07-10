use strict;
use warnings;

use Test::More;
use Sub::Go;

{
    my $ret = 10 >> go { $_ * 10 };
    is( $ret, 100, 'assign num' );
}
{
    my $ret = 10 >> go { $_ * 10 } go { $_ * 2 };
    is( $ret, 200, 'assign num chained' );
}
{
    my $ret = [1..10] >> go { $_ * 10 };
    is( $ret, 10, 'arr to scalar num' );
}
#{
    #my @ret = @{ [1..3] ~~ go { $_ * 2 } };
    #is( join(',',@ret), '2,4,6', 'arr num' );
#}

{
    my @rs = ( { name=>'jack', age=>20 }, { name=>'joe', age=>45 } );
    @rs ~~ sub { warn shift->{name} };
    @rs ~~ go { $_->{name} = 'sue' };
    is( join(',',map { $_->{name} } @rs), 'sue,sue', 'rs modify' );
}

done_testing;
