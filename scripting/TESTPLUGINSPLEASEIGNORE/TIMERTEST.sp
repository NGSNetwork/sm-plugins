/*
* What we learn from this: delete may not be used in a timer's callback. instead, just set the timer to null there.
* Make sure to null timers at the end if they are saved in a global variable. Some say you should null it at the
*	beginning of your "closing" statements within the timer callback, and I would agree as it saves us from
*	accidentally tripping in case our code glitches (do timer = null; PrintToServer("finish"); instead of the reverse.
* return Plugin_Stop to end a repeating timer, dont try and close its handle or randomly delete it or something.
* Our SMTimer methodmap is equivalent to an actual timer in every way.
*/

#include <sourcemod>
#include <ngsutils>

SMTimer timer3, timer4, timer6, timer8;
Handle nontimer, timer1, timer2, timer5, timer7;
int timer7iter = 0, timer8iter = 0;
SmartDB smartdb;

public void OnPluginStart() {
    nontimer = new ArrayList();
    timer1 = CreateTimer(0.1, timer1func);
    timer2 = CreateTimer(0.1, timer2func);
    timer3 = new SMTimer(0.1, timer3func);
    timer4 = new SMTimer(0.1, timer4func);
    timer5 = CreateTimer(0.1, timer5func);
    timer6 = new SMTimer(0.1, timer6func);
    timer7 = CreateTimer(0.1, timer7func, _, TIMER_REPEAT);
    timer8 = new SMTimer(0.1, timer8func, _, TIMER_REPEAT);
    PrintToServer("%i, %i, %i, %i, %i, %i, %i, %i, %i", nontimer, timer1, timer2, timer3, timer4, timer5, timer6, timer7, timer8);
    delete nontimer;
    delete timer1;
    //delete timer2;
    delete timer3;
    //delete timer4;
    // timer5 and timer6 are nulled within the callback.
    delete timer7;
    //delete timer8;
    PrintToServer("%i, %i, %i, %i, %i, %i, %i, %i, %i", nontimer, timer1, timer2, timer3, timer4, timer5, timer6, timer7, timer8);
    SMTimer checktimer = new SMTimer(1.0, checktimerfunc);
    SmartDB.Connect(DatabaseCallback);
    smartdb.VoidQuery("");
}

public void DatabaseCallback(Database db, const char[] error, any data)
{
	smartdb = view_as<SmartDB>(db);
}

public void QueryCallback(Database db, DBResultSet results, const char[] error, any data)
{
	
}


public Action timer1func(Handle timer) {
    PrintToServer("Deleted Handle timer1 shows up!");
}

public Action timer2func(Handle timer) {
    PrintToServer("Non-Deleted Handle timer2 shows up!");
}

public Action timer3func(Handle timer) {
    PrintToServer("Deleted SMTimer timer3 shows up!");
}

public Action timer4func(Handle timer) {
    PrintToServer("Non-Deleted SMTimer timer4 shows up!");
}

public Action timer5func(Handle timer) {
    PrintToServer("In Non-delete Handle timer5. Nulling!");
    timer5 = null;
}

public Action timer6func(Handle timer) {
    PrintToServer("In Non-delete SMTimer timer6. Nulling!");
    timer6 = null;
}

public Action timer7func(Handle timer) {
    PrintToServer("In Deleted repeating Handle timer7. Iteration %d!", timer7iter);
    if (timer7iter > 5)
    {
        PrintToServer("In Deleted repeating Handle timer7. Nulling!");
        timer7 = null;
        return Plugin_Stop;
    }
    timer7iter++;
    return Plugin_Continue;
}

public Action timer8func(Handle timer) {
    PrintToServer("In Non-delete repeating SMTimer timer8. Iteration %d!", timer8iter);
    if (timer8iter > 5)
    {
        PrintToServer("In Non-delete repeating SMTimer timer8. Nulling!");
        timer8 = null;
        return Plugin_Stop;
    }
    timer8iter++;
    return Plugin_Continue;
}

public Action checktimerfunc(Handle timer) {
    PrintToServer("After all types of timers are dead:");
    PrintToServer("%i, %i, %i, %i, %i, %i, %i, %i, %i", nontimer, timer1, timer2, timer3, timer4, timer5, timer6, timer7, timer8);
}