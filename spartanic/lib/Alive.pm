#==============================================================================
#
#  Alive Tick-Tack (German baby-word for Clock)
#
#  to show perl is still alive and working during long time runnings
#  prints out chars every n-th call 
#
#  Ralf Peine, Thu May 21 08:10:35 2015
#
#==============================================================================

package Alive;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION ='0.100';

use Perl5::Spartanic;

use base qw(Exporter);

our @EXPORT    = qw();
our @EXPORT_OK = qw(tack tacks get_tack_counter);
our %EXPORT_TAGS = (
    all => [@EXPORT_OK]
);

use Scalar::Validation qw(:all);

# === run state ==========================================

# do nothing if off > 0
my $off = 0;

# --- count and print ---------
sub on {
    $off = 0;
}

# --- count, but do not print ---------
sub silent {
    $off = 1;
}

# --- silent for existing instances,            -------
#     new created do nothing, also not counting -------
sub all_off {
    $off = 2;
}

# --- create a new tick tack ---------------------------------------------------
sub create {
    my $trouble_level = p_start;
    my %pars          = convert_to_named_params \@_;
    
    my $smaller      = npar -smaller      => -Default =>   1 => Int    => \%pars;
    my $bigger       = npar -bigger       => -Default =>  10 => Int    => \%pars;
    my $newline      = npar -newline      => -Default => 100 => Int    => \%pars;
    my $factor       = npar -factor       => -Default =>   1 => Int    => \%pars;
    my $smaller_char = npar -smaller_char => -Default => '.' => Scalar => \%pars;
    my $bigger_char  = npar -bigger_char  => -Default => ',' => Scalar => \%pars;
    my $name         = npar -name         => -Default => ''  => Scalar => \%pars;
    
    my $counter      = 0;
    my $counter_ref  = npar -counter_ref => -Default => \$counter => Ref     => \%pars;
    
    my $action       = npar -action      => -Optional             => CodeRef => \%pars;
        
    p_end \%pars;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub ----------------------------------------
 
    $name .= ' ' if $name =~ /\S$/;
    
    return sub { } if $off > 1;
    
    $smaller *= $factor;
    $bigger  *= $factor;
    $newline *= $factor;
    
    return sub {
        return if $off > 1;
        
        $$counter_ref++;
        
        if ($action) {
            local $_ = $$counter_ref;
            $action->();
        }
        
        return if $off;
        
        unless ($$counter_ref % $newline) {
            print "\n$name$$counter_ref ";
            return;
        }
        
        unless ($$counter_ref % $bigger) {
            print $bigger_char;
            return;
        }
        
        unless ($$counter_ref % $smaller) {
            print $smaller_char;
            return;
        }
    }    
}

# --- default tick tack ----------------------------------
my $tick;
my $counter;

# --- setup default tick tack ----------------------------
sub setup {
    $tick = create(@_, -counter_ref => \$counter); 
}

sub get_tack_counter {
    return \$counter;
}

sub tacks {
    return $counter;
}

# === the working function ===============================

# --- count and print default tick tack ------------------
sub tack {
    setup() unless $tick;
    $tick->();
    return $tick;
}

1;

__END__

=head1 NAME

Alive - Ticker to show perl is still alive and working during long time runnings
#  prints out chars every n-th call 

=head1 VERSION

This documentation refers to version 0.100 of Alive

=head1 SYNOPSIS

Shortest

  use Alive qw(tack);
  
  foreach my $i (1..10000) {
      tack;
  }

or fastest

  use Alive qw(tack);

  my $tick = tack;
  
  foreach my $i (1..10000) {
      $tick->();
  }

or individual

  my $ticker = Alive::create(
      -smaller      => 10,
      -bigger       => 100,
      -newline      => 500,
      -smaller_char => '+',
      -bigger_char  => '#',
      -name         => 'M ##',
  );

  foreach my $i (1..100000) {
      $ticker->();
  }

=head1 DESCRIPTION

Alive does the user inform, that perl job or script is still running by printing to console.

The following script

  $| = 1;
  use Alive;
  
  my $ticker = Alive::create(
        -newline      => 500,
  );
  
  foreach my $i (1..2000) {
      $ticker->();
  }

prints out this

  .........,.........,.........,.........,.........
  500 .........,.........,.........,.........,.........
  1000 .........,.........,.........,.........,.........
  1500 .........,.........,.........,.........,.........
  2000 

=head2 Methods

=head3 new() does not exist

There is no new(), use create instead(). Reason is, that there are no instances of Alive
that could be created.

=head3 create()

Alive::create() creates a ticker closure (a reference to a anonymous sub) for comfort
and fast calling without method name search and without args. The counter is inside.

Using instances is much more complicated to implement and slower. It is also impossible to 
misspell any instance method names, because there are no instance methods. 

=head3 $ticker->()

$ticker->() prints out a '.' every 10th call (default), a ',' every 100th call (default) and
starts a new line with number of calls done printed every 500th call (default is 1000).

=head2 Running Modes

There are 3 running modes that can be selected:

  Alive::on();        # default
  Alive::silent();
  Alive::all_off();

=head3 on()

Call of

  $ticker->();
  
prints out what is configured. This is the default.

=head3 silent()

Call of 

  $ticker->();
  
prints out nothing, but does the counting.

=head3 all_off()

If you need speed up, use

  Alive::all_off();

Now nothing is printed or counted by all tickers.
Selecting this mode gives you maximum speed without removing $ticker->() calls.
  
  my $ticker = Alive::create();
  
  Alive::all_off();

  my $tick_never = Alive::create();
  
call of $ticker->(); prints out nothing, but does the counting.

$tick_never has an empty sub which is same as

  my $tick_never = sub {};

This $tick_never will also not print out anything, if

  Alive::on();
  
is called to enable ticking.



=head2 Using multiple tickers same time

You can use multiple tickers same time, like in the following example.
ticker1 ticks all fetched rows and ticker2 only those, which are selected by
given filter. So you can see, if database select is still running or halted.

  use Alive;
  
  # Ticks all fetched rows
  my $ticker1 = Alive::create(
      -name    => '   S',
  );

  Alive::all_off();

  # To tick rows selected by filter
  my $ticker2 = Alive::create(
      -smaller      => 10,
      -bigger       => 100,
      -newline      => 500,
      -smaller_char => '+',
      -bigger_char  => '#',
      -name         => 'M ##',
  );

  Alive::silent();

  my @filtered_rows;

  foreach my $i (1..100000) {
      my $row = $sql->fetch_row()
      $ticker1->();
      
      if ($filter->($row)) {
          push (@filtered_rows, $row);
          $ticker2->();
      }
      
      Alive::on() if $i == 40000;
  }

=head1 SEE ALSO 

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 by Ralf Peine, Germany. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 DISCLAIMER OF WARRANTY

This library is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut



