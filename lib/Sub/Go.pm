package Sub::Go;
use strict;
use v5.10;
use Exporter::Tidy default=>[qw/go by yield get_out/];
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
#use overload '~' => \&over_go;

sub over_go {
    my $_go_self = shift;
    my $arg = shift;
    my $place = shift;
    #warn "V====>" . shift;
    #warn "PL====>" . $place;
   
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
        && !$_go_self->{yielded} && !$_go_self->{get_out_all} 
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

sub get_out_all {
    require PadWalker;
    my $self_ref;
    for( 2..3 ) {
        my $h = PadWalker::peek_my($_);
        $self_ref = $h->{'$_go_self'} and last;
    }
    !$self_ref and croak 'Misplaced yield. It can only be used in a go block.';
    my $self = ${ $self_ref };
    $self->{get_out_all} = 1;
    return bless {}, 'Sub::Go::Break';
}

sub get_out {
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

Sub::Go - DWIM when smart matching subs 

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

You don't need this module to use the smart match operator
to run a coderef, as such: 

    [1..10] ~~ sub {
        print shift;  
    };

The idea is to solve some of the inconveniences and inconsistencies
of using a code block in smart match:

    * proper handling of hashes
        - smart matching sends only the keys

    * no warnings on the useless use of smart match operator in void context

=head2 return values

Scalar is the only return value from a smart match expression,
and the same applies to C<go>. You can only return scalars, 
no arrays. 

    # broken:
    my @arr = [10..19] go { shift };
    # @arr == 1, $arr[0] == 10

Just use C<map> in this case, which is syntactically more sound anyway.

=cut


