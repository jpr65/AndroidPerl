#==============================================================================
#
#  Perl 5 Meta Info Database
#
#      Use PQL::Cache to build up PerlMeta data information system.
#
#  Part of Perl5::Spartanic::IDE
#
# Ralf Peine, Wed May 26 08:10:35 2015
#
#==============================================================================

package Perl5::MetaInfo::DB;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION ='0.120';

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

sub get_database {
    my $trouble_level     = p_start;
 
    my $self              = par self      => $is_self     => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
 
    return $self->{DB};
}

# --- create new, empty database ---------------------------------------
sub new_database {
    my $trouble_level     = p_start;
 
    my $self              = par self      => $is_self     => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    my $meta_infos = new PQL::Cache;

    $meta_infos->set_table_definition(
        class => {
            keys => [qw(ID fullname)],
            columns => [qw(namespace classname filename location line_nbr)]
        }
    );

    $meta_infos->set_table_definition(
        method => {
            keys => [qw(ID name)],
            columns => [qw(class_ID line_nbr)]
        }
    );
    
    $meta_infos->set_table_definition(
        namespace => {
            keys => [qw(ID name)],
        }
    );
    
    $meta_infos->set_table_definition(
        uses => {
            keys => [qw(ID class_ID used)],
        }
    );
    
    return $self->{DB} = $meta_infos;
}

# --- load database ---------------------------------------
sub read {
    my $trouble_level     = p_start;
 
    my $self              = par self      => $is_self     => shift;
    my $dump_db_file_name = par dump_file => ExistingFile => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    TRACE("# Load from file $dump_db_file_name");
    
    $self->{DB} = PQL::Cache::new_from_dump(
        "PerlMeta",
        $dump_db_file_name
    );
    
    my $classes = $self->get_database()->select(
	        what => [qw(ID fullname line_nbr)],
	        from => 'class',
	   );
    
    TRACE('# '.scalar (@$classes) . " class infos loaded.");
    
    my $methods = $self->get_database()->select(
        what  => 'all',
	       from  => 'method',
	   );

    TRACE('# '.scalar (@$methods) . " method infos loaded.");
}

# --- Dump internal database into file -----------------

sub write {
    my $trouble_level = p_start;
 
    my $self          = par self      => $is_self => shift;
    my $dump_file     = par dump_file => Filled   => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    $self->{DB}->prepare_dump();
    
    local $Data::Dumper::Purity = 1;
    
    my $fh = new FileHandle(">$dump_file");
    print $fh "package PerlMeta;\nsub load_cache {\n my ";
    print $fh Dumper($self->{DB});
    print $fh 'return $VAR1;'."\n}\n1;\n";
    close $fh;   
}

sub select_complete_namespace_infos {
    my $trouble_level = p_start;
 
    my $self          = par self        => $is_self => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $namespace_infos = $self->get_database()->select(
                    what  => 'all',
                    from  => 'namespace',
                );
                
    return $self->sort_by( name => $namespace_infos );        
}

sub select_complete_class_infos {
    my $trouble_level = p_start;
 
    my $self          = par self        => $is_self => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $class_infos = $self->get_database()->select(
                    what  => 'all',
                    from  => 'class',
                );
                
    return $self->sort_by( fullname => $class_infos );        

}
# --- select namespaces --------------------------------------------
sub select_namespaces {
    my $trouble_level   = p_start;
 
    my $self            = par self            => $is_self => shift;
    my $namespace_regex = par namespace_regex => Filled   => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $namespace_infos = $self->get_database()->select(
                    what  => all =>
                    from  => 'namespace',
                    where => [ name => {like => $namespace_regex}
                    ],
                );
                
    return $self->sort_by( name => $namespace_infos );        
}

# --- select classes -----------------------------------------------
sub select_classes {
    my $trouble_level = p_start;
 
    my $self          = par self        => $is_self => shift;
    my $class_regex   = par class_regex => Filled   => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $class_infos = $self->get_database()->select(
                    what  => [qw(ID fullname line_nbr)],
                    from  => 'class',
                    where => [ fullname => {like => $class_regex}
                    ],
                );
                
    return $self->sort_by( fullname => $class_infos );        
}

sub select_class_objects {
    my $trouble_level = p_start;
 
    my $self          = par self        => $is_self => shift;
    my $class_regex   = par class_regex => Filled   => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $class_infos = $self->get_database()->select(
                    what  => 'all',
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
        $self->get_database()->select(
            what  => [qw(ID class_ID name line_nbr)],
            from  => 'method',
            where => [ name => {like => $method_regex}
                     ],
        );

    return $self->
        sort_by(
            name =>
            $self->join_in_class($method_infos),
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

    my @class_ids = $self->preselect_class_ids($class_name_regex);
    
    my $method_infos = 
        $self->get_database()->select(
            what  => [qw(ID class_ID name line_nbr)],
            from  => 'method',
            where => [ class_ID => [@class_ids],
                       name     => {like => $method_name_regex},
                     ],
    );

    return $self->
        sort_by(
            name =>
            $self->join_in_class($method_infos),
    );
}

sub select_uses {
    my $trouble_level = p_start;
 
    my $self            = par self            => $is_self => shift;
    my $uses_name_regex = par uses_name_regex => Filled   => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $use_infos = $self->get_database()->select(
                    what  => [qw(ID class_ID used)] =>
                    from  => 'uses',
                    where => [ used => {like => $uses_name_regex }
                    ],
    );
    
    return $self->
        sort_by(
            name =>
            $self->join_in_class($use_infos),
    );
}

sub select_uses_of_classes {
    my $trouble_level = p_start;
 
    my $self             = par self            => $is_self => shift;
    my $class_name_regex = par class_name_regex  => Filled   => shift;
    my $uses_name_regex  = par uses_name_regex => Filled   => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my @class_ids = $self->preselect_class_ids($class_name_regex);
    
    my $use_infos = $self->get_database()->select(
                    what  => [qw(ID class_ID used)] =>
                    from  => 'uses',
                    where => [ class_ID => [@class_ids],
                               used     => {like => $uses_name_regex }
                    ],
    );
    
    return $self->
        sort_by(
            name =>
            $self->join_in_class($use_infos),
    );
}

sub preselect_class_ids {
    my $trouble_level = p_start;
 
    my $self              = par self              => $is_self => shift;
    my $class_name_regex  = par class_name_regex  => Filled   => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $class_infos = $self->get_database()->select(
                    what  => [qw(ID)],
                    from  => 'class',
                    where => [ fullname => {like => $class_name_regex}
                    ],
    );
        
    return map { $_->{ID}; } @$class_infos;    
}

# --- Add infos of class to method infos ---------------------------
sub join_in_class {
    my $trouble_level = p_start;
 
    my $self          = par self        => $is_self => shift;
    my $element_list  = par element_list => ArrayRef => shift;

    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
        
    my %class_ids_hash = map { $_->{class_ID} ? ($_->{class_ID} => 1) : (1, 1); } @$element_list;
        
    my @class_ids = sort keys %class_ids_hash;
    # say "# class Ids @class_ids";
        
    my $class_infos_selection = $self->get_database()->select(
        what  => [qw(ID fullname)],
        from  => 'class',
        where => [ ID => {in => [@class_ids] }
        ],
    );
    
    # auto_report($class_infos_selection);
    
    my %class_infos = map { $_->{ID} => $_; } @$class_infos_selection;
        
    foreach my $element_info (@$element_list) {
        my $class_id = delete $element_info->{class_ID} || "1";
        my $class_info_ref = $class_infos{$class_id};
        
        $element_info->{class} 
            = $class_info_ref
            ? $class_info_ref->{fullname}
            : "?$class_id";
    }
    
    return $element_list;
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

# so import of Log::Trace is not needed
sub TRACE { say "@_";};

1;
