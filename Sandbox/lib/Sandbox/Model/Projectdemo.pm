package Sandbox::Model::Projectdemo;
use Moose;
use MooseX::Method::Signatures;

#BEGIN { extends 'ListOfThings::Project' }
BEGIN { extends 'Catalyst::Model' }

# There are number of projects. Each project has
#  * ID
#  * Title
#  * Pipeline
#  * Length
#  * Priority

# There are a number of engineers. Each engineer has
#  * ID
#  * Name
#  * Efficiency curve
#  * Assigned projects

# Generate projects
#
method project_list($query = {}) {
  unless ( $self->{projectlist} ) {
    my @titleword = qw(build decom new server upgrade for japan india desk
                       tiger jaguar stack old doc bank mq hub rv market
                       trader payment rollout china virtual infra 3.1
                       7.5 ems ett work station used outdated spare cluster
                       loan site team cheetah all of dev prod bcp role host
                       to from unix windows linux solaris aix investigate
                       find inventory hongkong singapore australia
                       taiwan exchange co-host client san local disk
                       expand grow reduce top xlm mds database app
                       low high support environment);
    my @pipeline = qw(ficc equity infra gmt transition);
    my @priority = qw(critical important high bau low);
    my $numprojects = 5 + int rand 120;
    for my $id ( 1 .. $numprojects ) {
      my $title = ucfirst join ' ',
                  map $titleword[rand $#titleword], 0 .. 1+int(rand 3);
      push @{ $self->{projectlist} }, {
        id       => $id,
        size     => ( int rand 250 ),
        pipeline => $pipeline[rand $#pipeline],
        priority => $priority[rand $#priority],
        title    => $title,
      };
    }
  }
  #$self->{projectlist} = [
  #  { abc=>123, def=>456 },
  #  { abc=>234, def=>567 },
  #];
  return @{ $self->{projectlist} };
  #return $self->{projectlist};
  #return [ qw(1 2 3) ];
  #$self->{list} = [ qw(1 2 3) ];
  #return $self->{list};
}

# Generate list of engineers
#
method engineer_list {
  unless ( $self->{engineerlist} ) {
    my $id = 1;
    for my $name ( qw(John Joe Jack Jill) ) {
      push @{ $self->{engineerlist} }, {
        id => $id++,
        name => $name,
        efficiency => ( int 4 + rand 7 ),
      };
    }
  }
  return @{ $self->{engineerlist} };
}

# Each engineer has a number of slots matching efficiency
# Each slot has a number of projects assigned
#
method assignment {
  my @prj = $self->project_list();
  my @eng = $self->engineer_list();

  # Delete previous assignment
  delete $_->{slot} for @eng;
  for my $p ( @prj ) {
    my $randeng = int rand 1+$#eng;
    my $randslot = int rand $eng[$randeng]{efficiency};
    push @{ $eng[$randeng]{slot}[$randslot] }, $p;
  }

  #use Data::Dumper;
  #warn Dumper @eng;
  return @eng;
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
