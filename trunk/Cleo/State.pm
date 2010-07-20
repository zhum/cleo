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

#
# Constructor
# Args: states list.
#       First state is initial
#
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

#
#  Add new state names
#  Args: state names list
#
sub add_states(){
    my $self=shift;
    foreach my $i (@_){
        $self->{states}->{$i}={};
    }
}

#
#  Add new event rules.
#  Args: a list of triplets like
#        state, event, new_state, ...
#
#  e.g. add_events('first','a','a_state',
#                  'first','b','b_state'
#
#  ALL STATES MUST BE DEFINED EARLY!!!
#
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

#
#  Add hook-functions to call when several state is leaved
#
#  Args: triplets 'state', 'event', 'hook'
#  state and event can be 'default' (called on any state/event)
#  hook must be code reference
#
#  Args to hook function: old_state, event, new_state
#
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

#
#  Add hook-functions to call when several state is entered
#
#  Args: triplets 'state', 'event', 'hook'
#  state and event can be 'default' (called on any state/event)
#  hook must be code reference
#
#  Args to hook function: old_state, event, new_state
#
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

#
#  Process an event
#  Args: event name
#
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

