#==============================================================================
#
#  Template for Scalar::Validation
#
#      Class description
#
# Ralf Peine, Fri May * 09:00 2015
#
#==============================================================================

package Template::Scalar::Validation;

use strict;
use vars qw($VERSION);
$VERSION ='0.101';

use v5.10;
use Perl5::Spartanic;

# local cpan adaptions, currently not released on CPAN, but stored in github
use lib '../spartanic/lib';

use Scalar::Validation qw(:all);

# --- rule to validate class, don't remove the () !! --------------------
my ($is_self) = is_a (__PACKAGE__);

# === Creation =======================================================================
# --- Create Instance -----------------
sub new
{
    my $caller = $_[0];
    my $class  = ref($caller) || $caller;

    # let the class go
    my $self = {};
    bless $self, $class;

    $self->_init();

    return $self;
}

# --- _init ------------------------------------------------------------------
sub _init
{
    my ($self        # instance_ref
        ) = @_;

    # do something like
    # $self->{DB}              = undef;
}

# --- method description ---------------------------------------
sub method_arg_pos {
    my $trouble_level     = p_start;
    my $self              = par self      => $is_self     => shift;
    
    my $dump_db_file_name = par dump_file => ExistingFile => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    warn "*** No sub body implemented!!";
}

# --- method description ---------------------------------------
sub method_arg_named {
    my $trouble_level     = p_start;
    my $self              = par self => $is_self => shift;
    my %pars              = convert_to_named_params \@_;
    
    my $dump_db_file_name = npar -dump_file => ExistingFile => \%pars;
    # additional parameters
    
    p_end \%pars;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    warn "*** No sub body implemented!!";
}


# --- method description ---------------------------------------
sub method_arg_mixed {
    my $trouble_level     = p_start;
    my $self              = par self => $is_self => shift;

    my $dump_db_file_name = par dump_file  => ExistingFile      => shift;
    # additional parameters
    
    my $npars             = build_named_params \@_;
    
    my $html_doc_path     = npar -html_doc => Filled => $npars;
    # additional parameters
    
    p_end $npars;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    warn "*** No sub body implemented!!";
}

warn "*** Remove following lines!!";

my $instance = new Template::Scalar::Validation;

$instance->method_arg_pos("template_scalar_validation.pm");
$instance->method_arg_named(-dump_file => "template_scalar_validation.pm");
$instance->method_arg_mixed("template_scalar_validation.pm",
                            -html_doc => 'bla');

say "Test of template complete!"
