#==============================================================================
#
#  Perl 5 Meta Info Database
#
#      Use PQL::Cache to build up PerlMeta data information system.
#
#  Part of Perl5::Spartanic::IDE
#
# Ralf Peine, Fri May 01 09:00 2015
#
#==============================================================================

package Perl5::MetaInfo::DB;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION ='0.101';

use v5.10;
use Perl5::Spartanic;

use Data::Dumper;

use Report::Porf qw(:all);
use Scalar::Validation qw(:all);
use PQL::Cache qw (:all);

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

    $self->{DB}              = undef;
}

# --- load database ---------------------------------------
sub read {
    my $trouble_level     = p_start;
 
    my $self              = par self      => $is_self     => shift;
    my $dump_db_file_name = par dump_file => ExistingFile => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    say "# Load from file $dump_db_file_name";
    $self->{DB} = PQL::Cache::new_from_dump(
        "PerlMeta",
        $dump_db_file_name
    );
    
    my $classes = $self->{DB}->select(
	        what => [qw(ID fullname line_nbr)],
	        from => 'class',
	   );
    
    say '# '.scalar (@$classes) . " class infos loaded.";
    
    my $methods = $self->{DB}->select(
        what  => 'all',
	       from  => 'method',
	   );

    say '# '.scalar (@$methods) . " method infos loaded.";
}

# --- select classes -----------------------------------------------
sub select_classes {
    my $trouble_level = p_start;
 
    my $self          = par self        => $is_self => shift;
    my $class_regex   = par class_regex => Filled   => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $class_infos = $self->{DB}->select(
                    what  => [qw(ID fullname line_nbr)],
                    from  => 'class',
                    where => [ fullname => {like => $class_regex}
                    ],
                );
                
    return $self->sort_by( fullname => $class_infos );        
}

sub select_methods {
    my $trouble_level = p_start;
 
    my $self          = par self         => $is_self => shift;
    my $method_regex  = par method_regex => Filled   => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $method_infos = 
        $self->{DB}->select(
            what  => [qw(ID class_ID name line_nbr)],
            from  => 'method',
            where => [ name => {like => $method_regex}
                     ],
        );

    return $self->
        sort_by(
            name =>
            $self->join_class_to_method($method_infos),
    );
}

sub select_methods_of_classes {
    my $trouble_level = p_start;
 
    my $self              = par self              => $is_self => shift;
    my $class_name_regex  = par class_name_regex  => Filled   => shift;
    my $method_name_regex = par method_name_regex => Filled   => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $class_infos = $self->{DB}->select(
                    what  => [qw(ID fullname line_nbr)],
                    from  => 'class',
                    where => [ fullname => {like => $class_name_regex}
                    ],
    );
        
    my @class_ids = map { $_->{ID}; } @$class_infos;
    
    my $method_infos = 
        $self->{DB}->select(
            what  => [qw(ID class_ID name line_nbr)],
            from  => 'method',
            where => [ class_ID => [@class_ids],
                       name     => {like => $method_name_regex},
                     ],
    );

    return $self->
        sort_by(
            name =>
            $self->join_class_to_method($method_infos),
    );
}

# --- Add infos of class to method infos ---------------------------
sub join_class_to_method {
    my $trouble_level = p_start;
 
    my $self          = par self      => $is_self     => shift;
    my $method_list   = par method_list => ArrayRef => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
        
    my %class_ids_hash = map { $_->{class_ID} ? ($_->{class_ID} => 1) : (1, 1); } @$method_list;
        
    my @class_ids = sort keys %class_ids_hash;
    # say "# class Ids @class_ids";
        
    my $class_infos_selection = $self->{DB}->select(
        what  => [qw(ID fullname)],
        from  => 'class',
        where => [ ID => {in => [@class_ids] }
        ],
    );
    
    # auto_report($class_infos_selection);
    
    my %class_infos = map { $_->{ID} => $_; } @$class_infos_selection;
        
    foreach my $method_info (@$method_list) {
        my $class_id = delete $method_info->{class_ID} || "1";
        my $class_info_ref = $class_infos{$class_id};
        
        $method_info->{class} 
            = $class_info_ref
            ? $class_info_ref->{fullname}
            : "?$class_id";
    }
    
    return $method_list;
}

sub sort_by {
    my $trouble_level = p_start;
 
    my $self          = par self        => $is_self => shift;
    my $sort_column   = par sort_column => Filled   => shift;
    my $rows          = par rows        => ArrayRef => shift; 
    my $sort_mode     = par sort_mode   => -Default => String 
                                        => -Enum    => [qw (String Numbers)] => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
            
    # say "sort mode $sort_mode";

    my @sorted_rows
            = lc($sort_mode) eq 'string'
            ? sort {($a->{$sort_column}||'') cmp ($b->{$sort_column}||'')} @$rows
            : sort {($a->{$sort_column}||'0') <=> ($b->{$sort_column}||'0')} @$rows
            ; 
    return \@sorted_rows
}

1;
