#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define CVAR_FLAGS		FCVAR_NOTIFY

int
    heal_num = 1,
    heal_ci[32],
    heal_hp[32],
    heal_max[32];

float
    ut_time = 0.2;

Handle
    heal_find[32];

bool
    IsGive[32];

ConVar
    gheal_num,
    gut_time;

public Plugin myinfo = 
{
    name        = "l4d2_aidkithots",
    author      = "77",
    description = "医疗包缓慢回复",
    version     = "1.0",
    url         = "N/A"
}

public void OnPluginStart()
{
    gheal_num  	= CreateConVar("l4d2_first_aid_kit_heal_amount", "1",   "医疗包每次回复的生命值 (Max in 20s [heal_time(s) * (heal_health_max / heal_amount) <= 20.0s]).", CVAR_FLAGS, true, 1.0);
    gut_time  	= CreateConVar("l4d2_first_aid_kit_heal_time",   "0.1", "医疗包回复生命值的时间间隔.", CVAR_FLAGS, true, 0.1, true, 5.0);

    HookEvent("round_start", Event_RoundStart); //回合开始.
    HookEvent("heal_success", HealSuccess);     //幸存者治疗

    gheal_num.AddChangeHook(ConVarChanged);
    gut_time.AddChangeHook(ConVarChanged);

    for (int i = 0; i < 32 ; i++)
    {
        heal_ci[i] = 0;
    }

    AutoExecConfig(true, "l4d2_aidkithots");//生成指定文件名的CFG.
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
    heal_num = gheal_num.IntValue;
    ut_time  = gut_time.FloatValue;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 0; i < 32 ; i++)
    {
        if (heal_find[i] != null)
        {
            delete heal_find[i];
        }
        IsGive[i] = false;
    }
}

public void HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int client      = GetClientOfUserId(event.GetInt("userid"));
    int subject     = GetClientOfUserId(event.GetInt("subject"));
    int heal_health = event.GetInt("health_restored");

    if (IsSurvivor(client) && IsSurvivor(subject))
    {
        int new_hp = GetClientHealth(subject);
        int old_hp = new_hp - heal_health;
        SetEntProp(subject, Prop_Send, "m_iHealth", old_hp);
        heal_hp[subject]   = 0;
        heal_max[subject]  = heal_health;
        IsGive[subject] = true;
        if (heal_find[subject] != null)
        {
            delete heal_find[subject];
        }
        if (heal_find[subject] == null)
        {
            heal_find[subject] = CreateTimer(ut_time, GHP, subject, TIMER_REPEAT);
        }
        heal_ci[subject] ++;
        CreateTimer(20.0, DT, subject);
    }
}

public Action GHP(Handle timer, int client)
{
    if (IsSurvivor(client) && IsPlayerAlive(client) && IsPlayerState(client))
    {
        if (IsGive[client])
        {
            GiveClientHP(client);
        }
    }
    else
    {
        IsGive[client] = false;
    }

    return Plugin_Continue;
}

void GiveClientHP(int client)
{
    if (heal_hp[client] + heal_num > heal_max[client])
    {
        int give_hp = heal_max[client] - heal_hp[client];
        SetSurvivorHealth(client, give_hp);
        IsGive[client] = false;
    }
    else
    {
        SetSurvivorHealth(client, heal_num);
        heal_hp[client] += heal_num;
    }
}

public Action DT(Handle timer, int client)
{
    heal_ci[client] --;
    if (heal_ci[client] <= 0)
    {
        if (heal_find[client] != null)
        {
            delete heal_find[client];
        }
    }

    return Plugin_Continue;
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

void SetSurvivorHealth(int attacker, int iReward)
{
	int iHealth = GetClientHealth(attacker);
	int tHealth = GetPlayerTempHealth(attacker);

	if (tHealth == -1)
		tHealth = 0;
	
	if (iHealth + tHealth + iReward > 100)
	{
		float overhealth, fakehealth;
		overhealth = float(iHealth + tHealth + iReward - 100);
		if (tHealth < overhealth)
			fakehealth = 0.0;
		else
			fakehealth = float(tHealth) - overhealth;
		
		SetEntPropFloat(attacker, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(attacker, Prop_Send, "m_healthBuffer", fakehealth);
	}
		
	if ((iHealth + iReward) < 100)
	{
		SetEntProp(attacker, Prop_Send, "m_iHealth", iHealth + iReward);
	}
	else
	{
		SetEntProp(attacker, Prop_Send, "m_iHealth", iHealth > 100 ? iHealth : 100);
	}
}

//获取虚血值.
int GetPlayerTempHealth(int client)
{
    static Handle painPillsDecayCvar = null;
    if (painPillsDecayCvar == null)
    {
        painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
        if (painPillsDecayCvar == null)
            return -1;
    }

    int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
    return tempHealth < 0 ? 0 : tempHealth;
}

//正常状态.
bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}