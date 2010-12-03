=pod

=head1 NAME

Cleo::State - Simple implementation of state machine

=head1 SYNOPSIS

    use Cleo::State;
    use Error qw(:try);

    # call on state change
    sub hook($$$){
        print "Leave '$_[0]' > '$_[1]' > '$_[2]'\n";
    }

    # call on end state
    sub exit_hook($$$){
        print "EXIT!!! '$_[0]' > '$_[1]' > '$_[2]'\n";
    }


    # new State Machine
    # start state = 'start'
    # end state   = 'exit'
    $st = new Cleo::State('start','exit');

    # add some states...
    $st->add_states('step1','step2','step3');


    # add some rules...
    # format is: state, incoming_event, new_state
    # state can be 'default' = any state (not for new_state!!!)
    # event can be 'default' = any state
    $st->add_events(
        'start','a','step1',
        'start','b','step2',
        'start','c','step3',
        'step1','a','step1',
        'step1','default','step2',
        'step2','default','step3',
        'step3','c','exit',
        'step3','default','step1',
        'exit','default','exit');

    # add some hook functions
    # 'leave_hooks' are called on leaving any state
    $st->add_leave_hooks(
        'exit', 'default', \&exit_hook,
        'default', 'default', \&hook
        );

    # execute!
    my @e=('a','a','b','b','c','c','c');

    while(@e){
        $x=shift(@e);
        $st->event($x);
    }

=head1 DESCRIPTION

 This module emulates state machine.
 Created state machine has several states. New states can be added. State is
 described only by name. Name 'default' is reserved and cannot be used.
 One state is selected to be initial and one - for finish. Theese states
 names are described at once and cannot be changed later.
 States are changed by rules. Each rule has form:
 (current state, input string, new state).
 Current state can be 'default', which means 'any state'. Input string also
 can be 'default', and matches any input string.

=head2 Methods

=over 6

=item * new

 Constructor.
 Args: state names list. First state is initial

Example: C<<< $sm=Cleo::State->new('start','state2','ooops'); >>>

=cut

package Cleo::State::Error;

use base qw(Error);
use overload ('""' => 'stringify');

sub new{
    my $self = shift;
    my $text = "" . shift;
    my @args = ();

    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1;  # Enables storing of stacktrace

    $self->SUPER::new(-text => $text, @args);
}
1;

package Cleo::State;

use strict;
use Exporter;

use Error;
use vars qw($VERSION @ISA @EXPORT);

$VERSION=1.0;
@ISA=();
@EXPORT = qw(new event add_states add_events add_enter_hooks add_leave_hooks);


sub new (){
    my $self ={};
    $self->{state}=$_[1];
    foreach my $i (@_){
        $self->{states}->{$i}={};
    }
    $self->{states}->{$_[1]}={};
    bless($self);

    return $self;
}

=item * add_states

    Adds new states to the machine.
    Args: state names list
    Example:

C<< $sm->add_states('state1','state2','ooops'); >>

=cut

sub add_states(){
    my $self=shift;
    foreach my $i (@_){
        $self->{states}->{$i}={};
    }
}

=item * set_state

    Force set current state
    No hooks or events are generated!
    Args: state name
    RET: 0 if ok, 1 if no such state was found
    Example:

C<< $sm->set_state('state2'); >>
=cut

sub set_state(){
    my ($self,$state)=@_;
    return 1 unless defined $self->{states}->{$state};
    $self->{state}=$state;
    return 0;
}

=item * add_events

    Add new event rules.
    Args: a list of triplets like
        state, event, new_state, ...

    ALL STATES MUST BE DEFINED EARLY!!!

    Example:

C<< add_events('state1','a','state2', 'state1','b','oops'); >>
=cut

sub add_events(){
    my ($self,$state,$event,$new_state);
    $self=shift;

    while(@_){
        $state=shift;
        $event=shift;
        $new_state=shift;

        if(!exists($self->{states}->{$state})){
            throw Cleo::State::Error("No such state: $state");
        }
        if(!exists($self->{states}->{$new_state})){
            throw Cleo::State::Error("No such state: $new_state");
        }
        $self->{states}->{$state}->{$event}=$new_state;
    }
}

=item * add_leave_hooks

  Add hook-functions to call when several state is leaved
  Args: triplets 'state', 'event', 'hook'
        state and event can be 'default' (called on any state/event)
        hook must be code reference
  Args to hook function: old_state, event, new_state
  Example:

C<< sub leave_handler1($$$){
          print "Leaving state $_[0] with $_[1] to state $_[2]\n";
        }
        add_leave_hooks('state1','a','leave_handler1',
                  'state1','b','leave_handler1'); >>
=cut

sub add_leave_hooks(){
    my ($self,$state,$event,$hook);
    $self=shift;

    while(@_){
        $state=shift;
        $event=shift;
        $hook=shift;

        if(($state ne 'default') and !exists($self->{states}->{$state})){
            throw Cleo::State::Error("No such state: $state");
        }
        if(ref($hook) ne 'CODE'){
            throw Cleo::State::Error("Hook for $state/$event is not a code block");
        }
        push @{$self->{leave}->{$state}->{$event}}, $hook;
    }
}

=item * add_enter_hooks
  Add hook-functions to call when several state is entered

  Args: triplets 'state', 'event', 'hook'
  state and event can be 'default' (called on any state/event)
  hook must be code reference

  Args to hook function: old_state, event, new_state
  Example:

C<< sub add_enter_hooks('start','a','state1', \
                                'start'.'b','state2'); >>
=cut
sub add_enter_hooks(){
    my ($self,$state,$event,$hook);
    $self=shift;

    while(@_){
        $state=shift;
        $event=shift;
        $hook=shift;

        if(!exists($self->{states}->{$state})){
            throw Cleo::State::Error("No such state: $state");
        }
        if(ref($hook) ne 'CODE'){
            throw Cleo::State::Error("Hook for $state/$event is not a code block");
        }
        push @{$self->{enter}->{$state}->{$event}}, $hook;
    }
}

=item * event

 Process an event
 Args: event name
 Example:

C<<< $sm->event('a'); >>>

=cut

sub event($$){
    my $self=shift;
    my $event=shift;
    my ($oldstate,$newstate);

    # which is new state?
    if(exists($self->{states}->{$self->{state}}->{$event})){
        $newstate=$self->{states}->{$self->{state}}->{$event};
    }
    elsif(exists($self->{states}->{$self->{state}}->{'default'})){
        $newstate=$self->{states}->{$self->{state}}->{'default'};
    }
    else{
        throw Cleo::State::Error("No rule for $self->{state}/$event");
    }

    # call hooks
    if(exists($self->{leave}->{$self->{state}}->{$event})){
        foreach my $i (@{$self->{leave}->{$self->{state}}->{$event}}){
            $i->($self->{state},$event,$newstate);
        }
    }
    elsif(exists($self->{leave}->{$self->{state}}->{default})){
        foreach my $i (@{$self->{leave}->{$self->{state}}->{default}}){
            $i->($self->{state},$event,$newstate);
        }
    }
    elsif(exists($self->{leave}->{default}->{$event})){
        foreach my $i (@{$self->{leave}->{default}->{$event}}){
            $i->($self->{state},$event,$newstate);
        }
    }
    elsif(exists($self->{leave}->{default}->{default})){
        foreach my $i (@{$self->{leave}->{default}->{default}}){
            $i->($self->{state},$event,$newstate);
        }
    }
    # change state
    $oldstate=$self->{state};
    $self->{state}=$newstate;

    # call hooks
    if(exists($self->{enter}->{$self->{state}}->{$event})){
        foreach my $i (@{$self->{enter}->{$self->{state}}->{$event}}){
            $i->($self->{state},$event,$newstate);
        }
    }
    elsif(exists($self->{enter}->{$self->{state}}->{default})){
        foreach my $i (@{$self->{enter}->{$self->{state}}->{default}}){
            $i->($self->{state},$event,$newstate);
        }
    }
    elsif(exists($self->{enter}->{default}->{$event})){
        foreach my $i (@{$self->{enter}->{default}->{$event}}){
            $i->($self->{state},$event,$newstate);
        }
    }
    elsif(exists($self->{enter}->{default}->{default})){
        foreach my $i (@{$self->{enter}->{default}->{default}}){
            $i->($self->{state},$event,$newstate);
        }
    }
}

1;

=back

=head1 LICENSE

This is released under the Artistic 
License. See L<perlartistic>.

=head1 AUTHOR

Sergey Zhumatiy (serg@parallel.ru)

=head1 SEE ALSO
L<perlpod>, L<perlpodspec>


=cut


