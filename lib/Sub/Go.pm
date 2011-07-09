package Sub::Go;
use strict;
use v5.10;
use Exporter::Tidy default=>[qw/go yield skip stop/];
use Carp;

# get rid of this annoying message
my $old_warn_handler = $SIG{__WARN__}; 
$SIG{__WARN__} = sub { 
    if ($_[0] !~ /^Useless use of smart match in void context/) {
        goto &$old_warn_handler if $old_warn_handler;
        warn(@_);
    }
};

use overload '~~' => \&over_go;

sub over_go {
    my $_go_self = shift;
    my $arg = shift;
    my $place = shift;
   
    return unless defined $arg;
    my $code = $_go_self->{code};
    my $ret = [];
    $_go_self->{ret} = $ret;
    given( ref $arg ) { 
        when( 'HASH' ) {
            while( my ($k,$v) = each %$arg ) {
                push @$ret, $code->( $k,$v );
            }
        }
        when( 'ARRAY' ) {
            for( @$arg ) {
                my $r = $code->( $_ );
                last if ref $r eq 'Sub::Go::Break';
                push @$ret, $r;
            }
        }
        when( 'CODE' ) {
            for( $arg->() ) { 
                my $r = $code->( $_ );
                last if ref $r eq 'Sub::Go::Break';
                push @$ret, $r;
            }
        }
        when( 'GLOB' ) {
            while( <$arg> ) {
                my $r = $code->( $_ );
                last if ref $r eq 'Sub::Go::Break';
                push @$ret, $r;
            }
        }
        default {
            push @$ret, $code->( $arg );
        }
    }
    if( ref $_go_self->{rest} eq __PACKAGE__
        && !$_go_self->{yielded} && !$_go_self->{stop} 
        ) {
        if( @$ret > 1 ) {
            $_go_self->{by} 
                ? $_go_self->{rest}->{code}->( @$ret )
                : @$ret ~~ $_go_self->{rest}; 
        } else {
            $_go_self->{by} 
                ? $_go_self->{rest}->{code}->( @$ret )
                : $ret->[0] ~~ $_go_self->{rest};    
        }
    } else {
        #wantarray ? @$ret : $ret->[0];
        @$ret > 1 ? @$ret : $ret->[0];
    }
};

sub stop {
    require PadWalker;
    my $self_ref;
    for( 2..3 ) {
        my $h = PadWalker::peek_my($_);
        $self_ref = $h->{'$_go_self'} and last;
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
    for( 2..3 ) {
        my $h = PadWalker::peek_my($_);
        $self_ref = $h->{'$_go_self'} and last;
    }
    !$self_ref and croak 'Misplaced yield. It can only be used in a go block.';
    my $self = ${ $self_ref };
    $self->{yielded} = 1;
    $self->{rest}->{code}->( @_ ); 
}

sub go(&;@) {
    my ($code, $rest, $xx ) = @_;
    die "noo" if $xx;
    return bless { code=>$code, rest=>$rest }, __PACKAGE__;
}

sub by(&;@) {
    my ($code, $rest ) = @_;
    return bless { code=>$code, rest=>$rest, by=>1 }, __PACKAGE__;
}


1;

=pod

=head1 NAME

Sub::Go - smart matching sub power

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

    %h ~~ go {
        my ($k,$v) = @_;
        say "key $k, value $v";
    };

    # combine with signatures, or Method::Signatures
    #   for improved horsepower

    use Method::Signatures;
    %h ~~ go func($x,$y) {
    };

=head1 DESCRIPTION

This module imports a sub called C<go> into your package 
that overloads the smart match operator.

You don't need this module to run the smart match operator
with closures. This should work perfectly fine in your perl (>5.10):

    [1..10] ~~ sub {
        print shift;  
    };

The idea is to solve some of the inconveniences and inconsistencies
of using a code block in smart match:

    * proper handling of hashes, with keys and values
        - smart matching sends only the keys
    * chaining of sub blocks
    * no warnings on the useless use of smart match operator in void context

=head2 chaining

You can chain C<go> statements together, in the reverse direction
as you would with C<map> or C<grep>.

    print 10 ~~ go { return $_[0] * 2 }
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
        # runs 99 times
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

=head1 BUGS

This is pre-alfa. Everything could change tomorrow.

L<PadWalker>, a dependency, acts strangely in perl 5.14.1. 

=head1 SEE ALSO

L<autobox::Core> - has an C<each> method that can be chained together

=cut

