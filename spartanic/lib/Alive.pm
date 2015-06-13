#==============================================================================
#
#  Alive Tick-Tack (German baby-word for clock)
#
#  to show perl is still alive and working during long time runnings
#  prints out chars every n-th call 
#
#  Ralf Peine, Wed May 26 18:10:35 2015
#
#==============================================================================

package Alive;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION ='0.110';

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
    my $newline      = npar -newline      => -Default =>  50 => Int    => \%pars;
    my $factor       = npar -factor       => -Default =>  10 => Int    => \%pars;
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

  my $tick = Alive::create(
      -smaller      => 10,
      -bigger       => 100,
      -newline      => 500,
      -smaller_char => '+',
      -bigger_char  => '#',
      -name         => 'M ##',
  );

  foreach my $i (1..100000) {
      $tick->();
  }

=head1 DESCRIPTION

Alive does inform the user that perl job or script is still running by printing to console.

The following script

  $| = 1;
  use Alive qw(:all);
  
  foreach my $i (1..2000) {
      tack;
  }

prints out this

  .........,.........,.........,.........,.........
  500 .........,.........,.........,.........,.........
  1000 .........,.........,.........,.........,.........
  1500 .........,.........,.........,.........,.........
  2000 

=head2 Methods

=head3 new() does not exist

There is no new(), use create() instead. Reason is, that there are no instances of Alive
that could be created.

=head3 create()

Alive::create() creates a tick closure (a reference to a anonymous sub) for comfort
and fast calling without method name search and without args. The counter is inside.

Using instances is much more work to implement, slower and not so flexible.

=head4 Parameters

  # name        # default: description
  -smaller      #  1: print every $smaller * $factor call $smaller_char 
  -bigger       # 10: print every $bigger  * $factor call $bigger_char 
  -newline      # 50: print every $newline * $factor call "\n$name$$counter_ref"
  -factor       # 10:
  -smaller_char # '.'
  -bigger_char  # ','
  -name         # '': prepend every new line with it
  -counter_ref  # reference to counter that should be used
  -action       # action will be called by every call of tack; or $tick->();


=head3 setup()

Setup create the default ticker tack with same arguments as in create, except that

  # -counter_ref => ignored
  
will be ignored.

=head3 tack or $tick->()

$tick->() prints out a '.' every 10th call (default), a ',' every 100th call (default) and
starts a new line with number of calls done printed every 500th call (default).

=head3 tacks()

returns the value of the counter used by tack.

=head3 get_tack_counter()

returns a reference to the counter variable used by tack for fast access.

=head2 Running Modes

There are 3 running modes that can be selected:

  Alive::on();        # default
  Alive::silent();
  Alive::all_off();

=head3 on()

Call of

  $tick->(); or tack;
  
prints out what is configured. This is the default.

=head3 silent()

Call of 

  $tick->(); tack;
  
prints out nothing, but does the counting.

=head3 all_off()

If you need speed up, use

  Alive::all_off();

Now nothing is printed or counted by all ticks.
Selecting this mode gives you maximum speed without removing $tick->() calls.
  
  my $tick = Alive::create();
  
  Alive::all_off();

  my $tick_never = Alive::create();
  
call of $tick->(); prints out nothing and does not count.

$tick_never has an empty sub which is same as

  my $tick_never = sub {};

This $tick_never will also not print out anything, if

  Alive::on();
  
is called to enable ticking.

=head2 Using multiple ticks same time

You can use multiple ticks same time, like in the following example.
tick1 ticks all fetched rows and tick2 only those, which are selected by
given filter. So you can see, if database select is still running or halted.
But start ticking not before more than 40000 rows processed. So don't
log out for small selections.

  use Alive;
  
  # Ticks all fetched rows
  my $tick1 = Alive::create(
      -factor => 100,
      -name   => '   S',
  );

  my $matches = 0;

  # To tick rows selected by filter
  my $tick2 = Alive::create(
      -factor       => 10,
      -smaller_char => '+',
      -bigger_char  => '#',
      -name         => 'M ##',
      -counter_ref  => \$matches,
  );

  Alive::silent();

  my @filtered_rows;

  foreach my $i (1..100000) {
      my $row = $sql->fetch_row();
      $tick1->();
      
      if ($filter->($row)) {
          push (@filtered_rows, $row);
          $tick2->();
      }
      
      Alive::on() if $i == 40000;
  }
  
  say qq();
  say "$matches rows matched to filter.";
  
It will print out something like:

  .....#....,.........,........+.,.......+..,.........+
     S 45000 .........+,......+...,.....+....,.......+..,.....+....
     S 50000 .....+....,........
  M ## 500 .,......+...,...+......,.....+....
     S 55000 +.........,..+.......,.........,+.........,+.........
     S 60000 .+........,+.........,#.......+..,......+...,..+.......
     S 65000 .........,+.......+..,........+.,....+.....,.+........
     S 70000 .......+..,......#...,........+.,........+.,.........
     S 75000 ..+.......,......+...,....+.....,..+.......,.....+....
     S 80000 ....+.....,.........+,.........,........#.,.......+..
     S 85000 ..+.......,+........+.,.........+,........+.,.........
     S 90000 .......+..,......+...,......+...,...#......,....+.....
     S 95000 +.........,..+.....+..,.........,+.........,.+........+
     S 100000 
  987 rows matched to filter.

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



