package Sub::Go;
use strict;
use v5.10;
use Exporter::Tidy default => [ qw/go yield skip stop/ ];
use Carp;

# get rid of this annoying message
my $old_warn_handler = $SIG{ __WARN__ };
$SIG{ __WARN__ } = sub {
    if ( $_[ 0 ] !~ /^Useless use of smart match in void context/ ) {
        goto &$old_warn_handler if $old_warn_handler;
        warn( @_ );
    }
};

use overload '~~' => \&over_go;
use overload '>>' => \&over_go_assign;

sub over_go_assign {
    $_[0]->{assign};
    goto \&over_go;
}

sub over_go {
    my $_go_self = shift;
    my $arg      = shift;
    my $place    = shift;

    return unless defined $arg;
    my $code = $_go_self->{ code };
    my $ret  = [];
    #$_go_self->{ret} = $ret;
    if ( ref $arg eq 'ARRAY' ) {
        for ( @$arg ) {
            my $r = $code->($_);
            last if ref $r eq 'Sub::Go::Break';
            push @$ret, $r;
        }
    }
    elsif ( ref $arg eq 'HASH' ) {
        while ( my ( $k, $v ) = each %$arg ) {
            push @$ret, $code->( $k, $v );
        }
    }
    elsif ( ref $arg eq 'GLOB' ) {
        while ( <$arg> ) {
            my $r = $code->( $_ );
            last if ref $r eq 'Sub::Go::Break';
            push @$ret, $r;
        }
    }
    elsif ( ref $arg eq 'CODE' ) {
        for ( $arg->() ) {
            my $r = $code->( $_ );
            last if ref $r eq 'Sub::Go::Break';
            push @$ret, $r;
        }
    }
    else {
        push @$ret, $code->( $arg ) for $arg;
    }

    if (   ref $_go_self->{rest} eq __PACKAGE__
        && !$_go_self->{yielded}
        && !$_go_self->{stop} )
    {
        if ( @$ret > 1 ) {
            $_go_self->{by}
                ? $_go_self->{rest}->{code}->( @$ret )
                : $arg ~~ $_go_self->{rest};
        }
        else {
            $_go_self->{ by }
                ? $_go_self->{rest}->{code}->( @$ret )
                : $arg ~~ $_go_self->{rest};
        }
    }
    else {
        return @$ret > 1 ? @$ret : $ret->[ 0 ];
    }
}

sub stop {
    require PadWalker;
    my $self_ref;
    for ( 2 .. 3 ) {
        my $h = PadWalker::peek_my( $_ );
        $self_ref = $h->{ '$_go_self' } and last;
    }
    !$self_ref and croak 'Misplaced yield. It can only be used in a go block.';
    my $self = ${ $self_ref };
    $self->{stop} = 1;
    return bless {}, 'Sub::Go::Break';
}

sub skip {
    return bless {}, 'Sub::Go::Break';
}

sub yield {
    require PadWalker;
    my $self_ref;
    for ( 2 .. 3 ) {
        my $h = PadWalker::peek_my( $_ );
        $self_ref = $h->{ '$_go_self' } and last;
    }
    !$self_ref and croak 'Misplaced yield. It can only be used in a go block.';
    my $self = ${ $self_ref };
    $self->{yielded} = 1;
    $self->{rest}->{code}->( @_ );
}

sub go(&;@) {
    my ( $code, $rest ) = @_;
    return bless { code => $code, rest => $rest }, __PACKAGE__;
}

sub by(&;@) {
    my ( $code, $rest ) = @_;
    return bless { code => $code, rest => $rest, by => 1 }, __PACKAGE__;
}

1;

=pod

=head1 NAME

Sub::Go - DWIM sub blocks for smart matching 

=head1 SYNOPSIS

    use Sub::Go;

    [ split /,/ => 'a,b,c' ] ~~ go {
        print shift;  # prints a, then b, then c
    };

    undef ~~ go {
        # never gets called...
    };

    '' ~~ go {
        # ...but this does
    };

    # hashes

    %h ~~ go {
        my ($k,$v) = @_;
        say "key $k, value $v";
    };

    # in-place modify

    my @rs = ( { name=>'jack', age=>20 }, { name=>'joe', age=>45 } );
    @rs ~~ go { $_->{name} = 'sue' };

    # filehandles 

    open my $fh, '<', 'file.txt';
    $fh ~~ go {
        my $line = shift;
        say ; # line by line 
    };

    # chaining
    
    @arr ~~ go { s/$/one/ } go { s/$/two/ };

    # combine with signatures, or Method::Signatures
    #   for improved horsepower

    use Method::Signatures;

    %h ~~ go func($x,$y) {
        say $x * $y;
    };

=head1 DESCRIPTION

In case you don't know, smart matching C<~~> against C<sub> blocks
will run the block once (for scalars) or, distributively, many times
for arrays and hashes:

    [1..10] ~~ sub { say shift };
    @arr ~~ sub { say shift };
    %h ~~ sub { ... };
    # ...

The motivation behind this module is to improve
the experience of using a code block with the smart match 
operator.

This module imports a sub called C<go> into your package. 
This sub returns an object that overloads the smart match operator.

=head2 Benefits

=head3 proper handling of hashes, with keys and values

Smart matching sends only the keys, which may be useless
if your hash is anonymous.

   %h ~~ go { my ($k,$v) = @_;
        say "key=$k, value=$v";
   };

=head3 in-place modification of the matched array

    my @arr = qw/a b c/;
    @arr ~~ go { s{$}{x} };
    # now @arr is qw/ax bx cx/

=head3 context variables

Loading of both C<$_> and C<@_> variables with the current value

Smart matching only uses C<@_>.

=head3 prevent the block from running on undef values

    undef ~~ go { say "never runs" };
    undef ~~ sub { say "but we do" };

=head3 chaining of sub blocks

So you can bind several blocks. 

=head3 no warnings on the useless use of smart match operator in void context

=head2 Pitfalls

A smart match (and most overloaded operators)
can only return scalar values. So you can only expect
to get a scalar from your block chaining.

=head1 FEATURES

=head2 chaining

You can chain C<go> statements together, in the reverse direction
as you would with C<map> or C<grep>.

    say 10 ~~ go { return $_[0] * 2 }
                go { return $_[0] + 1 }; 
    # 21  

The next C<go> block in the chain gets the return value
from the previous block. 

    [1..3] ~~ go { say "uno " . $_[0]; 100 + $_[0] }
              go { say "due " . shift };

    # uno 1    
    # uno 2    
    # uno 3    
    # due 101
    # due 102
    # due 103

To interleave two C<go> blocks
use the C<yield> statement.

    [1..3] ~~ go { say "uno " . $_[0]; yield 100 + $_[0] } go { say "due " . shift };

    # uno 1    
    # due 101
    # uno 2    
    # due 102
    # uno 3    
    # due 103

You can interrupt a C<go> block with an special return 
statement: C<return skip>.
    
    [1..1000] ~~ go {
        # after 100 this block won't execute anymore
        return skip if $_[0] > 100;
    } go {
        # but this one will keep going up to the 1000th
    };

Or break the whole chain at a given point:

    [1..1000] ~~ go {
        # after 100 this block won't execute anymore
        return stop if $_[0] > 100;
    } go {
        # this one will run 100 times too
    };

=head2 return values

Scalar is the only return value from a smart match expression,
and the same applies to C<go>. You can only return scalars, 
no arrays. 

    # good
    my $value = 'hello' ~~ go { "$_[0] world" } # hello world
    
    # broken:
    my @arr = [10..19] go { shift }; # @arr == 1, $arr[0] == 10

Just use C<map> in this case, which is syntactically more sound anyway.

=head1 IMPORTS

=head3 go CODE

The main function here. Don't forget the semicolon at the end.

=head3 yield

Iterate once over the next block in the chain.

=head3 skip 

Tell the iterator to stop executing the block.
    
    return skip;

=head3 stop 

Tell the iterator to stop executing all blocks.

    return stop;

=head1 BUGS

This is pre-alfa on a test-drive. Everything you ever knew 
could change tomorrow.

L<PadWalker>, a dependency, may segfault in perl 5.14.1.

=head1 SEE ALSO

L<autobox::Core> - has an C<each> method that can be chained together

=cut

