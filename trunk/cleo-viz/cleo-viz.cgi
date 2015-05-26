#!/usr/bin/perl

my $force_html=0;  #debug
my $def_mode='table';

my $myname='/cgi-bin/cleo-viz.cgi';
my $tmpl_prefix='/var/www/readonly';
my $cleo_xml_prefix='/tmp';
my $jquery='/jq/jq.js';
my $css='/cleoviz.css';

my @all_queues=('regular','hdd','hddmem','bigmem','test');
use vars qw($lang $mode $user $queue $rqueue $cols $task %user_names %tasks_ids);
use vars qw(%ru_trans %gg_trans %en_trans);

#my $img_file='/var/www/apache2/cleo_viz_image.tmpl';
#my $index_file='/var/www/apache2/cleo_viz_index.tmpl';
my $img_file="$tmpl_prefix/cleo_viz_image.tmpl";
my $index_file="$tmpl_prefix/cleo_viz_index.tmpl";
my $table_file="$tmpl_prefix/cleo_viz_table.tmpl";
my $used_img   ='/img/used.gif';
my $extra_img  ='/img/extra.png';
my $blocked_img='/img/blocked.png';
my $unknown_img='/img/unknown.png';
my $free_img   ='/img/free.png';
my $wait_img   ='/img/wait.gif';


require "$tmpl_prefix/cleo-viz-locale.pm";



my $image_extra_attrs='width="8px" height="8px"'; #"vspace='1'";

use XML::Parser;
use CGI;

my $img;                # global result html text. UGLY, but FAST.
my ($count, $percent,$trans);

my $xmlp = new XML::Parser(
    Handlers => {
        Start => \&handle_start,
        End   => \&handle_end,
        Char  => \&handle_char}
    );

my @ru_month=('??','января','февраля','марта','апреля','мая','июня',
    'июля','августа','сентября','октября','ноября','декабря');
my @en_month=('??','january','february','march','april','may','jun',
    'july','august','september','october','november','december');
my @gg_month=('??','енварько','фивралько','марто','опрелько','маико','юнько',
    'юлько','авгуздо','синтибря','актибря','наибря','дикабря');
my @ru_days=('вс','пн','вт','ср','чт','пт','сб','вс');
my @gg_days=('вс','пн','вт','ср','чт','пт','сб','вс');
my @en_days=('sun','mon','tue','thu','wed','fri','sat','sun');


{
    my $index=0;
    sub next_style(){
        return (++$index)%16;
    }
}

sub date2str($$$$$$){
    #$attrs{day},$attrs{month},$attrs{year},$attrs{hours},$attrs{minutes},$attrs{seconds});
    
    if($lang eq 'ru'){
        return sprintf('%2d %s %02d:%02d:%02d',
            $_[0],$ru_month[$_[1]],$_[3],$_[4],$_[5]);
    }
    if($lang eq 'gg'){
        return sprintf('%2d %s %02d:%02d:%02d',
            $_[0],$gg_month[$_[1]],$_[3],$_[4],$_[5]);
    }
    return sprintf('en %2d %s %02d:%02d:%02d',
            $_[0],$en_month[$_[1]],$_[3],$_[4],$_[5]);
}

sub time2str($$$$$$){
    return sprintf('%4d %s %02d:%02d:%02d',
        $_[0],$trans->{days},$_[3],$_[4],$_[5]);
}

sub day2str($){
    if($lang eq 'ru'){
        return $ru_days[$_[0]];
    }
    if($lang eq 'gg'){
        return $ru_days[$_[0]];
    }
    return $en_days[$_[0]];
}

sub  handle_end(){
    my $t=$_[1];
#    warn "<<$t\n";
    pop @stack;
}

sub top(){
    return $stack[$#stack];
}

sub handle_char(){
#    warn "CHAR: '$_[1]'\n";
    my $t=top();
    my $data=$_[1];
    chomp $data;
    my $top_1=$#stack-1;
    my $top_2=$top_1-1;
    
    if($t eq 'total-free'){
        $free_total{$queue}=$data;
    }elsif($t eq 'total-number'){
        $total_cpus{$queue}=$data;
    }elsif($t eq 'blocked-count'){
        $blocked_cpus{$queue}=$data;
    }elsif($t eq 'block_reason'){
        $nodes{$cur_node}->{reasons}->{$data}=1;
#        warn "BAD node!\n" if $cur_node eq '';
    }elsif($t eq 'tasks-total'){
        $tasks_all{$queue}=$data;
    }elsif($t eq 'tasks-running'){
        $tasks_run{$queue}=$data;
    }elsif($t eq 'tasks-prerun'){
        $tasks_pre{$queue}=$data;
    }elsif($t eq 'tasks-blocked'){
        $tasks_block{$queue}=$data;
    }elsif($t eq 'tasks-queued'){
        $tasks_queue{$queue}=$data;
    }elsif($t eq 'tasks-completition'){
        $tasks_post{$queue}=$data;
    }elsif($t eq 'who'){
        $who=$data;
    }elsif($t eq 'reason'){
        if($stack[$#stack-3] eq 'task'){
            push @{$cur_task->{blocks}}, [$who,$data];
        }
    }elsif($t eq 'task_code'){
        $cur_task->{code}=$data;
    }elsif($t eq 'blocked'){
        $cur_task->{blocked}=$data;
    }elsif($t eq 'user'and $stack[$top_1] eq 'task'){
#!        warn "USER: $top_1 ($stack[$top_1]) ".join(';',@stack)."\n";
        $cur_task->{user}=$data;
        $user_names{$data}=1; # remeber all user names
        $tasks{$cur_task_id}->{user}=$data;
        $users{$data}=1;
    }elsif($t eq 'np' and $stack[$top_1] eq 'task'){
#!        warn "NP: $#stack-1 ".join(';',@stack)."\n";
        $cur_task->{np}=$data;
        $tasks{$cur_task_id}->{np}=$data;
    }elsif($t eq 'sexe' and $stack[$top_1] eq 'task'){
        $cur_task->{sexe}=$data;
    }
}

sub handle_start(){
    my $t=$_[1];
    shift; shift;
#    warn ">>$t: Attrs: ".join(';',@_)."\n";
    my %attrs=@_;
    my $t_1=top();
    push @stack, $t;
    
    if($t eq 'cleo-state'){
        $update=$attrs{'last-update'};
        $queue=$attrs{'queue'};
    }
    elsif(($t eq 'node') and ($t_1 eq 'cpus')){
        $cur_node=$attrs{nodename};
        $nodes{$cur_node}->{queue}=$queue;
#        if($cur_node eq ''){
#            warn ">>$t: Attrs: ".join(';',@_)."\n";
#            warn join(';',@stack)."\n";
#        }
    }
    elsif($t eq 'cpu'){
#        print "CPU $cur_node\n";
        ++$nodes{$cur_node}->{blocked} if($attrs{blocked});
        ++$nodes{$cur_node}->{cores};
        if($nodes{$cur_node}->{cores}>$max_cores){
            $max_cores=$nodes{$cur_node}->{cores};
        }
    }
    elsif($t eq 'mode'){
        $can_run{$queue}=$attrs{run};
        $can_queue{$queue}=$attrs{queue};
    }
    elsif($t eq 'task'){
        $cur_task_id="$queue $attrs{id}";
        $tasks_ids{$cur_task_id}=1; # remember tasks ids...
        $tasks{$cur_task_id}->{style}='x'.next_style();
        if($attrs{state} eq 'queued'){
            ++$tq;
            $queue{$queue}->{task_q}->[$tq]->{id}=$attrs{id};
            $queue{$queue}->{task_q}->[$tq]->{priority}=$attrs{priority};
            $cur_task=$queue{$queue}->{task_q}->[$tq];
        }
        elsif($attrs{state} eq 'run'){
#            warn "RUNNNN! $$attrs{id}\n";
            ++$tr;
            $queue{$queue}->{task_r}->[$tr]->{id}=$attrs{id};
            $queue{$queue}->{task_r}->[$tr]->{priority}=$attrs{priority};
            $cur_task=$queue{$queue}->{task_r}->[$tr];
        }
        elsif($attrs{state} eq 'pre-run'){
            ++$ts;
            $queue{$queue}->{task_s}->[$ts]->{id}=$attrs{id};
            $queue{$queue}->{task_s}->[$ts]->{priority}=$attrs{priority};
            $cur_task=$queue{$queue}->{task_s}->[$ts];
        }
        elsif($attrs{state} eq 'ending'){
            ++$te;
            $queue{$queue}->{task_e}->[$te]->{id}=$attrs{id};
            $queue{$queue}->{task_e}->[$te]->{priority}=$attrs{priority};
            $cur_task=$queue{$queue}->{task_e}->[$te];
        }
        $cur_id=$attrs{id};
        $cur_task_state=$attrs{state};
    }
    elsif($t eq 'item' and $t_1 eq 'nodes'){
#        warn "YYYYY $attrs{node_name}";
        if($attrs{type} eq 'own'){
            if($attrs{extra}){
                ++$nodes{$attrs{node_name}}->{extra};
            }
            else{
                ++$nodes{$attrs{node_name}}->{used};
            }
            $nodes{$attrs{node_name}}->{ids}->{"$queue $cur_id"}=1;
        }
    }
    elsif($t eq 'start'){
        $cur_task->{start}=date2str($attrs{day},$attrs{month},
            $attrs{year},$attrs{hours},
            $attrs{minutes},$attrs{seconds}).
        ' ('.day2str($attrs{of_week}).')';
    }
    elsif($t eq 'timelimit'){
        if($cur_task_state eq 'run'){
            $cur_task->{limit}=date2str($attrs{day},$attrs{month},
                $attrs{year},$attrs{hours},
                $attrs{minutes},$attrs{seconds}).
            ' ('.day2str($attrs{of_week}).')';
        }
        else{
            $cur_task->{limit}=time2str($attrs{day},$attrs{month},
                $attrs{year},$attrs{hours},
                $attrs{minutes},$attrs{seconds});
        }
    }
    elsif($t eq 'added'){
        $cur_task->{added}=date2str($attrs{day},$attrs{month},
            $attrs{year},$attrs{hours},
            $attrs{minutes},$attrs{seconds}).
        ' ('.day2str($attrs{of_week}).')';
    }
}
######################################################################
######################################################################
######################################################################

sub template_subst_trans($){
    my $str=$_[0];
    my $r;

    foreach my $i (keys(%$trans)){
        $r=$trans->{$i};
        $$str =~ s/\#$i\#/$r/g;
    }
    
}

sub template_subst_hash($$){
    my ($str,$hash)=@_;
    my $r;
    
    foreach my $i (keys(%$hash)){
        $r=$hash->{$i};
        $$str =~ s/\$$i\$/$r/g;
    }
}

sub template_subst_sub($$$$;$){
    my ($str,$name,$key_hash,$sub,$extra)=@_;
    my $newstr;
    
    for my $i (sort(keys(%$key_hash))){
        $newstr=$sub->($str,$key_hash,$i,$extra);
        $$str =~ s/\$$name\$/$newstr/g;
    }
}

sub node_print($){
    $nn=$nodes{$_[0]};
    my ($j,$txt,$alt);
    
    for($i=1;$i<=$nn->{used};++$i){
        $txt=join(';',keys(%{$nn->{ids}}));
        $alt="$_[0]:$i $txt";
        $nn->{$i}="<img src='$used_img' $image_extra_attrs ALT='$alt' TITLE='$alt'/>";
    }
    for($j=1;$j<=$nn->{extra};++$i,++$j){
        %alt="$_[0]:$i $trans->{extra} $txt";
        $nn->{$i}="<img src='$extra_img' $image_extra_attrs ALT='$alt' TITLE='$alt'/>";
    }
    for($j=1;$j<=$nn->{blocked};++$i,++$j){
        $txt=join('; ',keys(%{$nn->{reasons}}));
        $alt="$_[0]:$i $trans->{blocked} $txt";
        $nn->{$i}="<img src='$blocked_img' $image_extra_attrs ALT='$alt' TITLE='$alt'/>";
    }
    for(;$i<=$nn->{cores};++$i,++$j){
        $alt="$_[0]:$i $trans->{free}";
        $nn->{$i}="<img src='$free_img' $image_extra_attrs ALT='$alt' TITLE='$alt'/>";
    }
    # $node-01-01:1  -> <img src=....>
    $img =~ s/\$$_[0]:(\d+)\$/$nn->{$1}/g;
}

#nodes table print
sub node_t_print($){
    my $n=$_[0];
    my ($span,$block,$st,$est);
    #my ($id,$queue) = ($n =~ /(\S+)\s+(\S+)/);

    if($nodes{$n}->{blocked}>0){
        $block='class=\'block_cpu\'';
    }
    else{
        $block='';
    }
    print "<tr><td class='queue_$queue' width='$percent\%'><div $block id='node_$count'>$n<br>$nodes{$n}->{queue}</div></td>";
    ++$count;
    my $free=$max_cores-
        ($nodes{$n}->{used}+$nodes{$n}->{extra}+$nodes{$n}->{blocked});
    if($nodes{$n}->{used}>0){
        $span=$percent*$nodes{$n}->{used};
        print "<td width='$span\%' colspan='$nodes{$n}->{used}'>";
        for $i (keys(%{$nodes{$n}->{ids}})){
            $i =~ /\S+\s+(\S+)/;
            if(($user ne '') and ($user ne $tasks{$i}->{user})){
                $st=$est='ignored_task';
            }
            elsif(($task ne '') and ($task ne $i)){
                $st=$est='ignored_task';
            }
            else{
                $st=$tasks{$i}->{style};
                $est='extra';
            }
            print "<div class='$st' user='$tasks{$i}->{user}'>$1<br>$tasks{$i}->{user}</div>";
        }
        print '</td>';
    }
    if($nodes{$n}->{extra}>0){
        $span=$percent*$nodes{$n}->{extra};
        print "<td width='$span\%' colspan='$nodes{$n}->{extra}' class='$est'>&nbsp;+ $nodes{$n}->{extra}</td>";
    }
    if($nodes{$n}->{blocked}>0){
        $span=$percent*$nodes{$n}->{blocked};
        print "<td width='$span\%' colspan='$nodes{$n}->{blocked}' class='block_cpu'>&nbsp;</td>";
    }
    if($free>0){
        $span=$percent*$free;
        print "<td width='$span\%' colspan='$free' class='free_cpu'>&nbsp;</td>";
    }
    print "</tr>\n";
    return $ret;
}

sub error_handler($){
    print "<center>Sorry, $_[0].<center>\n</body></html>\n";
}

sub subst_unknown($$){
    my ($ret,$rep)=$@;
    $ret =~ s/\$\$\$/$rep/g;
    return $ret;
}

sub print_js_vars(){
    my $n;
    print "\n<script type=text/javascript>\n<!--\n";
    $n=0;
    foreach my $i (sort(keys(%user_names))){
        print " users[$n]=\"$i\"\n";
        ++$n;
    }
    $n=0;
    foreach my $i (sort(keys(%tasks_ids))){
        print " tasks[$n]=\"$i\"\n";
        ++$n;
    }
    print "-->\n</script>\n";
}
sub print_json_vars(){
    print '{ "users":[';
    print join(',',map {"\"$_\""} sort(keys(%user_names)));
    print '],"tasks":[';
    print join(',',map {"\"$_\""} sort(keys(%tasks_ids)));
    print ']}';
}
######################################################################
######################################################################
######################################################################



#
# %tasks_run/_all/_pre/_block/_post/_queue {queue}
# %free_total/total_cpus/blocked_cpus {queue}
# nodes{node} ->
#                %reasons
#                %ids -> ...
#                blocked (cores count)
#                cores
#                extra   (cores count)
#                used    (cores count)
#
# queue{queue} ->
#                %task_q/task_r/task_s/task_e (queued,run,start,end)
#    @task_* ->
#              id
#              priority
#              user
#              np
#              sexe
#              start
#              limit
#              added
#    %tasks ->
#              "queue id" -> np/user/style
#
# can_run{queue} / and_queue{queue}

my $valid=0;

my $cgi=new CGI;
$lang=$cgi->param('lang');
$lang = 'ru' if($lang eq '');

$trans=($lang eq 'ru'?\%ru_trans:
       ($lang eq 'gg'?\%gg_trans:
       \%en_trans));

$cols=$cgi->param('cols');
$cols=6 if ($cols<0 or $cols>8);

$user=$cgi->param('user');
$task=$cgi->param('task');

$rqueue=$cgi->param('q');

if($rqueue eq '' or $rqueue eq 'all'){
    @queues=split(/,/,$q);
    @queues=@all_queues if($#queues<1);
}
else{
    @queues=($rqueue);
}

$mode=$cgi->param('mode');
$mode='html' if ($mode eq '');
#@queues=('hddmem','regular');
if($mode eq 'image'){
    @queues=@all_queues;
}
my $ctype = ( $mode eq 'vars'?'text/j-son':'text/html');
print CGI::header(-type=>$ctype,
             -pragma=>'No-Cache',
             -charset=>'utf-8');

foreach my $file (@queues){
    $tq=-1; #current queued task index
    $tr=-1; #current running task index
    $tp=-1; #current starting task index
    $te=-1; #current ending task index
    $queue='';

    if(open(IN,"$cleo_xml_prefix/cleo-xml-status.$file")){
        $xmlp->parsefile("$cleo_xml_prefix/cleo-xml-status.$file");
        $valid=1;
    }
    else{
        error_handler("Cannot open Cleo status file for $file queue");
        exit 0;
    }
    #warn "parsed /tmp/cleo-xml-status.$file\n";
    
    $all_free_total+=  $free_total{$queue};
    $all_total_cpus+=  $total_cpus{$queue};
    $all_blocked_cpus+=$blocked_cpus{$queue};
    $all_tasks_all+=   $tasks_all{$queue};
    $all_tasks_run+=   $tasks_run{$queue};
    $all_tasks_pre+=   $tasks_pre{$queue};
    $all_tasks_block+= $tasks_block{$queue};
    $all_tasks_queue+= $tasks_queue{$queue};
    $all_tasks_post+=  $tasks_post{$queue};
}

if($valid==0 || $max_cores ==0){
    error_handler("No processors found");
    exit 0;
}

my %global_v=(free_total  => $all_free_total,
              used_cpus   => $used_cpus,
              total_cpus  => $all_total_cpus,
              blocked_cpus => $all_blocked_cpus,
              tasks_all   => $all_tasks_all,
              tasks_run   => $all_tasks_run,
              tasks_pre   => $all_tasks_pre,
              tasks_block => $all_tasks_block,
              tasks_queue => $all_tasks_queue,
              tasks_post  => $all_tasks_post,
              used_img    => $used_img,
              blocked_img => $blocked_img,
              extra_img   => $extra_img,
              unknown_img => $unknown_img,
              free_img    => $free_img,
              wait_img    => $wait_img
              );

if(($mode eq 'html') or ($force_html==1)){
    local $mode=$def_mode;
    prolog();
    #print_js_vars();
    print "<br><br><center><button id='start' onClick='do_request()'>$trans->{pressme}</button></center>\n";
}
elsif($mode eq 'vars'){
    print_json_vars();
}
elsif($mode eq 'tasks'){
    my ($st,$alt,$t);
    tasks_legenda();
    print "<center><table id='tasks_tbl' class='tasks_tbl'>\n";
    foreach my $q (@queues){
        #warn "queue: $q\n";

        print "<tr><td class='qname' colspan='7'><div id='queue' run='$tasks_run{$q}' all='$tasks_all{$q}'\
        pre='$tasks_pre{$q}' block='$tasks_block{$q}' post='$tasks_post{$q}'\
        queue='$tasks_queue{$q}' can_r='$can_run{$q}' can_q='$can_queue{$q}'>\
        $q ($trans->{total}: $total_cpus{$q}, $trans->{free_p}: $free_total{$q}, $trans->{block}: $blocked_cpus{$q})</div></td></tr>\n";

        print "<tr><td class='qname' colspan='7'><div>$trans->{total}: $tasks_all{$q} $trans->{running}: $tasks_run{$q}\
        $trans->{pre}: $tasks_pre{$q} $trans->{block}: $tasks_block{$q} $trans->{post}: $tasks_post{$q}\
        $trans->{queued}: $tasks_queue{$q} ";
        print $can_run{$q}? $trans->{can_run}: $trans->{not_can_run};
        print ' &nbsp; ';
        print $can_queue{$q}? $trans->{can_q}: $trans->{not_can_q};
        print "</div></td></tr>\n";

        print <<TABLE_HEAD;
        <tr><td class='qlegend'>$trans->{state}</td>
        <td class='qlegend'>$trans->{id}</td>
        <td class='qlegend'>$trans->{user}</td>
        <td class='qlegend'>$trans->{task}</td>
        <td class='qlegend'>$trans->{np}</td>
        <td class='qlegend'>$trans->{start}</td>
        <td class='qlegend'>$trans->{estimated_end}</td></tr>
TABLE_HEAD

        foreach $t (@{$queue{$q}->{task_r}}){
            next if(($user ne '') and ($user ne $t->{user}));
            next if(($task ne '') and ($task ne "$q $t->{id}"));
            print "<tr><td><div class='r_task'>$trans->{running}</td><td><div id='task_$t->{id}' class='r_task'>$t->{id}</div></td><td>\
            <div class='r_task'>$t->{user}</div></td><td><div class='r_task'>$t->{sexe}</div></td><td><div class='r_task'>$t->{np}</div></td><td>\
            <div class='r_task'>$t->{start}</td><td><div class='r_task'>$t->{limit}</div></td></tr>\n";
        }
        foreach $t (@{$queue{$q}->{task_s}}){
            next if(($user ne '') and ($user ne $t->{user}));
            next if(($task ne '') and ($task ne "$q $t->{id}"));
            print "<tr><td><div class='s_task'>$trans->{pre}</td><td><div id='task_$t->{id}' class='s_task'>$t->{id}</div></td><td>\
            <div class='s_task'>$t->{user}</div></td><td><div class='s_task'>$t->{sexe}</div></td><td>\
            <div class='s_task'>$t->{np}</div></td><td>\
            <div class='s_task'>$t->{added}</td><td><div class='s_task'>$t->{limit}</dev></td></tr>\n";
        }
        foreach $t (@{$queue{$q}->{task_e}}){
            next if(($user ne '') and ($user ne $t->{user}));
            next if(($task ne '') and ($task ne "$q $t->{id}"));
            print "<tr><td><div class='e_task'>$trans->{post}</td><td><div id='task_$t->{id}' class='e_task'>$t->{id}</div></td><td>\
            <div class='e_task'>$t->{user}</div></td><td><div class='e_task'>$t->{sexe}</div></td>\
            <td><div class='e_task'>$t->{np}</div></td><td>\
            <div class='e_task'>$t->{start}</td><td><div class='e_task'>$t->{limit}</div></td></tr>\n";
        }
        foreach $t (@{$queue{$q}->{task_q}}){
            next if(($user ne '') and ($user ne $t->{user}));
            next if(($task ne '') and ($task ne "$q $t->{id}"));
            $st=(($t->{blocked} > 0) ?
                $trans->{blocked}:
                $trans->{queued});
            $alt=(($t->{blocked} eq '') ? '': "alt='$t->{blocked}'");
            print "<tr $alt><td><div class='q_task'>$st</td><td><div id='task_$t->{id}' class='q_task' class='q_task'>$t->{id}</div></td><td>\
            <div class='q_task'>$t->{user}</div></td><td><div class='q_task'>$t->{sexe}</div></td><td><div class='q_task'>$t->{np}</div></td><td>\
            <div class='q_task'>$t->{added}</td><td><div class='q_task'>$t->{limit}</td></div></tr>\n";
        }
    }
    print "</table></center>\n";
}
elsif($mode eq 'table'){
    # nodes{node} ->
    #                %reasons
    #                %ids -> ...
    #                blocked (cores count)
    #                cores
    #                extra   (cores count)
    #                used    (cores count)
    #
    $count=0;
    $percent=int(100/$max_cores);
    
#    unless(open(IMG,"<$table_file")){
#        print "error4: Cannot open table file $table_file\n";
#        exit 1;
#    }
#    $img=join('',<IMG>);
#    close IMG;
    
    #header
    #print "<center><h>Nodes table</h></center>\n";
    table_legenda();
    print "<div class='table_bg_st'><table class='tbl_out'>\n  <tr><td class=table_out>\n";
    print "<table class='tbl_st'>\n";
    
    my $nnodes=int(keys(%nodes));
    my $interval=1+int($nnodes / $cols);
    my $col_count=0;

    foreach my $n (sort(keys(%nodes))){
        if($col_count == $interval){
            print "</table>\n</td><td><table class='tbl_st'>\n";
            $col_count=0;
        }
        ++$col_count;
        node_t_print($n);
    }
#    print $img;
    print "</table></table></div>\n";
}
elsif($mode eq 'image'){
    # nodes{node} ->
    #                %reasons
    #                %ids -> ...
    #                blocked (cores count)
    #                cores
    #                extra   (cores count)
    #                used    (cores count)
    #
    unless(open(IMG,"<$img_file")){
        print "error2: Cannot open image file $img_file\n";
        exit 1;
    }
    
    my @img=<IMG>;
    my $unknown="<img src='$unknown_img' ALT=\$\$\$ unknown' TITLE='unknown'/>";
    $img=join('',@img);
    
    foreach my $n (keys(%nodes)){
        node_print($n);
    }

    $global_v{users}=int(keys(%users));
    #my $users=keys(%users);

    #$img =~ s/\$users\$/$users/g;
    
    #my $used_cpus=$all_total_cpus-($all_blocked_cpus+$all_free_total);
    $global_v{used_cpus}=$all_total_cpus-($all_blocked_cpus+$all_free_total);
#    $img =~ s/\$free_total\$/$all_free_total/g;
#    $img =~ s/\$used_cpus\$/$used_cpus/g;
#    $img =~ s/\$total_cpus\$/$all_total_cpus/g;
#    $img =~ s/\$blocked_cpus\$/$all_blocked_cpus/g;
#    $img =~ s/\$tasks_all\$/$all_tasks_all/g;
#    $img =~ s/\$tasks_run\$/$all_tasks_run/g;
#    $img =~ s/\$tasks_pre\$/$all_tasks_pre/g;
#    $img =~ s/\$tasks_block\$/$all_tasks_block/g;
#    $img =~ s/\$tasks_queue\$/$all_tasks_queue/g;
#    $img =~ s/\$tasks_post\$/$all_tasks_post/g;

    template_subst_hash(\$img,\%global_v);
    template_subst_trans(\$img);
    $img =~ s/\$([^\$]+)\$/&subst_unknown($unknown,$1)/ge;

    print $img;
}
elsif($mode eq 'index'){
    unless(open(IMG,"<$index_file")){
        print "error3: Cannot open image file $index_file\n";
        exit 1;
    }
    my @img=<IMG>;
    my $img=join('',@img);

#    my $users=keys(%users);
#    $img =~ s/\$users\$/$users/g;
#    my $used_cpus=$all_total_cpus-($all_blocked_cpus+$all_free_total);
    $global_v{users}=int(keys(%users));

    #$img =~ s/\$users\$/$users/g;
    
    #my $used_cpus=$all_total_cpus-($all_blocked_cpus+$all_free_total);
    $global_v{used_cpus}=$all_total_cpus-($all_blocked_cpus+$all_free_total);
    template_subst_hash(\$img,\%global_v);
    template_subst_trans(\$img);
#    $img =~ s/\$free_total\$/$all_free_total/g;
#    $img =~ s/\$used_cpus\$/$used_cpus/g;
#    $img =~ s/\$total_cpus\$/$all_total_cpus/g;
#    $img =~ s/\$blocked_cpus\$/$all_blocked_cpus/g;
#    $img =~ s/\$tasks_all\$/$all_tasks_all/g;
#    $img =~ s/\$tasks_run\$/$all_tasks_run/g;
#    $img =~ s/\$tasks_pre\$/$all_tasks_pre/g;
#    $img =~ s/\$tasks_block\$/$all_tasks_block/g;
#    $img =~ s/\$tasks_queue\$/$all_tasks_queue/g;
#    $img =~ s/\$tasks_post\$/$all_tasks_post/g;
    print $img;
}
else{
    $mode=quotemeta($mode);
    print "<h1><center>Ooops! Mode $mode is not supported!</center></h1>";
}

if(($mode eq 'html') or ($force_html==1)){
    print '</div>';
    epilog();
}

sub prolog(){
    $cols=1 if($cols<1);
    $cols=8 if($cols>8);
    my $qlist='<option>'.join('</option><option>','all',@all_queues).'</option>';
    print <<_PROLOG;
<html><head><title>$tans->{title}</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>
<body>
<link rel="stylesheet" href="$css" type="text/css" media="all">
<script type='text/javascript' src='$jquery'></script>


<script type='text/javascript'>
<!--
function print_wait(){
\$("#wait").html("<center>$trans->{wait} <img src='$wait_img'></center>");
};

function empty_wait(){
\$("#wait").html("");
};

/*
var users=new Array
var tasks=new Array
*/
var data=""

var cols=$cols
var user="$user"
var task="$task"
var mode="$mode"
var queue="$qq"

trigger_tasks_table = function(){
  \$("#tasks_tbl > tbody> tr:even").addClass("even");
}

\$(document).ready(function(){
  update_users=function(){
    \$("#sel_user").empty()
    \$("#sel_user").append("<option></option>");
    /* load user list and tasklist */
    for(i=0;i<data.users.length;i=i+1){
      \$("#sel_user").append("<option>"+data.users[i]+"</option>");
    }
    \$("#sel_task").empty()
    \$("#sel_task").append("<option></option>");
    for(i=0;i<data.tasks.length;i=i+1){
      \$("#sel_task").append("<option>"+data.tasks[i]+"</option>");
    }
  }

  reload_users=function(){
    /*\$.getJSON("${myname}?mode=vars\&q="+queue,'',function(jsn){alert(jsn.users[1]);});*/
    \$.ajax({url: "${myname}?mode=vars\&q="+queue, dataType: 'json',
    success: function(jsn){data=jsn;update_users()},
    /*error: function(r,err){alert("ERROR"+err);}*/
    });
    /* enable/disable controls */
    if(mode == "image"){
      \$("#sel_task").attr("disabled", true);\$("#task_l").addClass("disabled");
      \$("#sel_user").attr("disabled", true);\$("#user_l").addClass("disabled");
      \$("#sel_queue").attr("disabled", true);\$("#queue_l").addClass("disabled");
      \$("#sel_cols").attr("disabled", true);\$("#cols_l").addClass("disabled");
    }
    if(mode == "index"){
      \$("#sel_task").attr("disabled", true);\$("#task_l").addClass("disabled");
      \$("#sel_user").attr("disabled", true);\$("#user_l").addClass("disabled");
      \$("#sel_queue").removeAttr("disabled");\$("#queue_l").removeClass("disabled");
      \$("#sel_cols").attr("disabled", true);\$("#cols_l").addClass("disabled");
    }
    if(mode == "table"){
      \$("#sel_task").removeAttr("disabled");\$("#task_l").removeClass("disabled");
      \$("#sel_user").removeAttr("disabled");\$("#user_l").removeClass("disabled");
      \$("#sel_queue").removeAttr("disabled");\$("#queue_l").removeClass("disabled");
      \$("#sel_cols").removeAttr("disabled");\$("#cols_l").removeClass("disabled");
      
      \$("div[user*='']").mousedown(function(){
        alert("!");
        \$("div").removeClass("ignored_task");
        a=\$(this).attr("user");
        \$("div[user!="+a+"]").addClass("ignored_task");
      });
    }
    if(mode == "tasks"){
      \$("#sel_task").removeAttr("disabled");\$("#task_l").removeClass("disabled");
      \$("#sel_user").removeAttr("disabled");\$("#user_l").removeClass("disabled");
      \$("#sel_queue").removeAttr("disabled");\$("#queue_l").removeClass("disabled");
      \$("#sel_cols").attr("disabled", true);\$("#cols_l").addClass("disabled");
    }
  }

  do_request=function(){
    /*alert("Req: lang=${lang}\&q="+queue+"\&mode="+mode+"\&cols="+cols+"\&user="+user+"\&task="+task);*/
    \$.ajax({
      data:       "lang=${lang}\&q="+queue+"\&mode="+mode+"\&cols="+cols+"\&user="+user+"\&task="+task,
      url:        "$myname",
      type:       "POST",
      dataType:   "text",
      timeout:    10000,
      beforeSend: print_wait,
      success:    function(answer){ \$("#info").html(answer); reload_users(); trigger_tasks_table();empty_wait();},
      error:      function(XHTMLHttpRequest, textStatus, err){ \$("#info").text(textStatus+';;'+err); }
    }); /* ajax */
  };
  \$("#sel_mode").change(function(){
    mode=\$("#sel_mode").val();
    do_request()
    });
  \$("#sel_user").change(function(){
    user=\$("#sel_user").val();
    if(mode != "image"){
        do_request()
    }
    user=''
    });
  \$("#sel_task").change(function(){
    task=\$("#sel_task").val();
    if(mode != "image"){
        do_request()
    }
    task=''
    });
  \$("#sel_queue").change(function(){
    queue=\$("#sel_queue").val();
    if(mode != "image"){
        do_request()
    }
    /*queue=''*/
    });
  \$("#sel_cols").change(function(){
    cols=\$("#sel_cols").val();
    if(mode != "image"){
        do_request()
      }
    });
  \$("#reload").click(do_request);
  
  \$("#sel_cols_$cols").select

  mode="image";
  reload_users();

  \$("#info").show();

  }); /* ready*/
-->
</script>


<h>$trans->{title}</h>
<form onSubmit="return false">
  <label for='mode' id='mode_l'>$trans->{modeform}:<select name='mode' id='sel_mode'>
  <option value=table>$trans->{nodeslist}</option>
  <option value=tasks>$trans->{taskslist}</option>
  <option value=image selected>$trans->{oneshot}</option>
  <option value=index>$trans->{shortinfo}</option>
  </select>
  <label for='user' id='user_l'>$trans->{userform}:<select name='user' id='sel_user'><option id="all_users">$trans->{all}</option></select>
  <label for='queue' id='queue_l'>$trans->{queueform}:<select name='queue' id='sel_queue'>$qlist</select>
  <label for='task' id='task_l'>$trans->{taskid}:<select name='task' id='sel_task'><option id="all_tasks">$trans->{all}</option></select>
  <label for='cols' id='cols_l'>$trans->{columns}:<select name='cols' id='sel_cols'>
    <option id='sel_cols_1'>1</option>
    <option id='sel_cols_2'>2</option>
    <option id='sel_cols_3'>3</option>
    <option id='sel_cols_4'>4</option>
    <option id='sel_cols_5'>5</option>
    <option id='sel_cols_6'>6</option>
    <option id='sel_cols_7'>7</option>
    <option id='sel_cols_8'>8</option>
  </select>
  <button id="reload">$trans->{reload}</button>
</form>
<div id='wait'></div><br>
<div id='info' style='display: none'>
_PROLOG
}

sub epilog(){
    my $qq=join(',',@queues);
    print <<_EPILOG;
</body></html>
_EPILOG
}

sub tasks_legenda(){
    print <<_T_LEGENDA;
<center><div></div></center><br>
_T_LEGENDA
}

sub table_legenda(){
    print <<_B_LEGENDA;
<center><div><table border=1 class='legenda'>
<tr><td><div class='free_cpu'>  $trans->{free_p}   </td>
<td><div class='extra'>  $trans->{extra}  </td>
<td><div class='block_cpu'>  $trans->{block}  </td>
<td><div class='ignored_task'>  $trans->{ignored}  </td>
<td>  $trans->{all_other}  </td></tr>
</table></div></center>
<br>
_B_LEGENDA
#<center><div><table border=1 class='legenda'>
#<tr><td width=100px><div class='free_cpu'>&nbsp;</div></td><td>$trans->{free_p}   </td></tr>
#<tr><td width=100px><div class='extra'>&nbsp;</div></td><td>$trans->{extra}  </td></tr>
#<tr><td width=100px><div class='block_cpu'>&nbsp;</div></td><td>$trans->{block}</td></tr>
#<tr><td width=100px><div class='ignored_task'>&nbsp;</div></td><td>$trans->{ignored}</td></tr>
#<tr><td width=100px>$trans->{all_other}</td><td>$trans->{task}</td></tr>
#</table></div></center>
#<br>
}


