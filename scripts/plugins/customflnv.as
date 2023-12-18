void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );

	g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, @CustomLights::PlayerKilled );
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @CustomLights::ClientDisconnect );
	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @CustomLights::ClientPutInServer );

	@CustomLights::g_iFlashlightRadius = CCVar( "fl-radius", 9, "Size of the light. (default: 9)", ConCommandFlag::AdminOnly );
	@CustomLights::g_iNightvisionRadius = CCVar( "nv-radius", 40, "Size of the light. (default: 40)", ConCommandFlag::AdminOnly );
	@CustomLights::g_flDrain = CCVar( "flnv-drain", 1.2f, "Rate at which the battery drains. (default: 1.2)", ConCommandFlag::AdminOnly );
	@CustomLights::g_flCharge = CCVar( "flnv-charge", 0.2f, "Rate at which the battery charges. (default: 0.2)", ConCommandFlag::AdminOnly );

	if( CustomLights::g_pFLNVThink !is null )
		g_Scheduler.RemoveTimer( CustomLights::g_pFLNVThink );

	if( CustomLights::g_pFLNVRainbowThink !is null )
		g_Scheduler.RemoveTimer( CustomLights::g_pFLNVRainbowThink );

	@CustomLights::g_pFLNVThink = g_Scheduler.SetInterval( "FLNV_Think", 0.1f );
	@CustomLights::g_pFLNVRainbowThink = g_Scheduler.SetInterval( "FLNV_RainbowThink", 0.15f );
}

void MapInit()
{
	g_SoundSystem.PrecacheSound( "player/hud_nightvision.wav" );
	g_SoundSystem.PrecacheSound( "items/flashlight2.wav" );

	if( CustomLights::g_bUseCustomFlashlightSound )
	{
		g_Game.PrecacheGeneric( "sound/" + CustomLights::SOUND_FLASHLIGHT_ON );
		g_Game.PrecacheGeneric( "sound/" + CustomLights::SOUND_FLASHLIGHT_OFF );
	}

	g_SoundSystem.PrecacheSound( CustomLights::SOUND_FLASHLIGHT_ON );
	g_SoundSystem.PrecacheSound( CustomLights::SOUND_FLASHLIGHT_OFF );

	CustomLights::g_PlayerLights.deleteAll();
	CustomLights::g_LightColors.deleteAll();
	CustomLights::ReadColors();
	CustomLights::g_bColorsLoaded = true;

	if( CustomLights::g_pFLNVThink !is null )
		g_Scheduler.RemoveTimer( CustomLights::g_pFLNVThink );

	if( CustomLights::g_pFLNVRainbowThink !is null )
		g_Scheduler.RemoveTimer( CustomLights::g_pFLNVRainbowThink );

	@CustomLights::g_pFLNVThink = g_Scheduler.SetInterval( "FLNV_Think", 0.0f );
	@CustomLights::g_pFLNVRainbowThink = g_Scheduler.SetInterval( "FLNV_RainbowThink", 0.15f );
}

namespace CustomLights
{

const string g_ColorFile = "scripts/plugins/flcolors.txt";
const string SOUND_FLASHLIGHT_ON = "items/flashlight1.wav";
const string SOUND_FLASHLIGHT_OFF = "items/flashlight1.wav";
const bool g_bUseCustomFlashlightSound = false;

const bool g_bShowFlashlightToAll = true;
const int g_iAttenuation = 5;
const float g_flDistanceMax = 2000.0f;
const int iLife	= 2;
const int g_iRainbowIncrement = 51;//1, 3, 5, 15, 17, 51, 85 
const Vector NV_COLOR(0, 255, 0);

CClientCommand flashlight( "flashlight", "Toggles custom flashlight on/off.", @ToggleLight );
CClientCommand nightvision( "nightvision", "Toggles night vision on/off", @ToggleLight );
CClientCommand fl_radius( "fl_radius", "Size of the light. (default: 9)", @LightSettings, ConCommandFlag::AdminOnly );
CClientCommand nv_radius( "nv_radius", "Size of the light. (default: 40)", @LightSettings, ConCommandFlag::AdminOnly );
CClientCommand flnv_drain( "flnv_drain", "Rate at which the battery drains. (default: 1.2)", @LightSettings, ConCommandFlag::AdminOnly );
CClientCommand flnv_charge( "flnv_charge", "Rate at which the battery charges. (default: 0.2)", @LightSettings, ConCommandFlag::AdminOnly );

CScheduledFunction@ g_pFLNVThink = null;
CScheduledFunction@ g_pFLNVRainbowThink = null;
CCVar@ g_flDrain;
CCVar@ g_flCharge;
CCVar@ g_iFlashlightRadius;
CCVar@ g_iNightvisionRadius;

dictionary g_PlayerLights;
dictionary g_LightColors;
bool g_bColorsLoaded = false;

array<string> @g_ColorListKeys;

enum LightModes
{
	MODE_FLASHLIGHT = 0,
	MODE_NIGHTVISION
};

class PlayerLightData
{
	bool bFlashlightOn;
	bool bNightvisionOn;
	bool bRainbow;
	Vector vecColor;
	Vector vecRainbowColor;
	int iBattery;
	float flLightTime;
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());
	PlayerLightData pData;
	g_PlayerLights[string(id)] = pData;

	reset(pPlayer);

	return HOOK_CONTINUE;
}

HookReturnCode PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
	reset(pPlayer);
	
	return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());

	if( g_PlayerLights.exists(string(id)) )
		g_PlayerLights.delete(string(id));

	//LightTurnOff( pPlayer, MODE_FLASHLIGHT );
	//LightTurnOff( pPlayer, MODE_NIGHTVISION );
 
	return HOOK_CONTINUE;
}

void reset( CBasePlayer@ pPlayer )
{
	if( pPlayer is null ) return;

	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());

	if( g_PlayerLights.exists(string(id)) )
	{
		PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );

		if( pData.bFlashlightOn )
			LightTurnOff( pPlayer, MODE_FLASHLIGHT );

		if( pData.bNightvisionOn )
			LightTurnOff( pPlayer, MODE_NIGHTVISION );

		pData.bRainbow = false;
		pData.vecRainbowColor = Vector(255, 0, 0);
		pData.iBattery = 100;
		pData.flLightTime = 0.0f;

		g_PlayerLights[string(id)] = pData;
	}
}

void ReadColors()
{
	File@ file = g_FileSystem.OpenFile( g_ColorFile, OpenFile::READ );
	if( file !is null and file.IsOpen() )
	{
		while( !file.EOFReached() )
		{
			string sLine;
			file.ReadLine( sLine );
			if( sLine.SubString(sLine.Length()-1,1) == " " or sLine.SubString(sLine.Length()-1,1) == "\n" or sLine.SubString(sLine.Length()-1,1) == "\r" or sLine.SubString(sLine.Length()-1,1) == "\t" )
					sLine = sLine.SubString( 0, sLine.Length()-1 );

			if( sLine.SubString(0,1) == "#" or sLine.IsEmpty() )
				continue;

			array<string> parsed = sLine.Split(" ");
			if( parsed.length() < 4 )
				continue;

			int iR = Math.clamp( 0, 255, atoi(parsed[1]) );
			int iG = Math.clamp( 0, 255, atoi(parsed[2]) );
			int iB = Math.clamp( 0, 255, atoi(parsed[3]) );
			Vector color = Vector( iR, iG, iB );
			g_LightColors[ parsed[0].ToLowercase() ] = color;
		}
		file.Close();

		@g_ColorListKeys = g_LightColors.getKeys();
	}
}

void ToggleLight( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	if( pPlayer !is null )
	{
		const string sCommand = args.Arg(0);
		LightModes uiMode = sCommand == ".flashlight" ? MODE_FLASHLIGHT : MODE_NIGHTVISION;

		if( args.ArgC() == 2 and args.Arg(1) == "help" )
			LightHelp(pPlayer, uiMode);
		else if( args.ArgC() == 2 and args.Arg(1) == "list" )
			LightList(pPlayer, uiMode);
		else if( pPlayer.IsAlive() )
		{
			int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());
			PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );
			string sPrefix = uiMode == MODE_FLASHLIGHT ? "[Flashlight]" : "[Nightvision]";

			if( args.ArgC() == 1 ) // no args supplied: use normal light colors
				pData.vecColor = uiMode == MODE_FLASHLIGHT ? Vector(128, 128, 128) : NV_COLOR;
			else if( args.ArgC() == 2 ) // one arg supplied; rainbow, random, randomcolor, or colorname
			{
				if( args.Arg(1) == "rainbow" )
				{
					if( sCommand == ".flashlight" and g_PlayerFuncs.AdminLevel( pPlayer ) < ADMIN_YES )
					{
						g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[Flashlight] That color is only for admins.\n" );
						return;
					}
					else pData.bRainbow = true;
				}
				else if( args.Arg(1) == "random" ) // random RGB
					pData.vecColor = Vector( Math.RandomLong(0, 255), Math.RandomLong(0, 255), Math.RandomLong(0, 255) );
				else if( args.Arg(1) == "randomcolor" ) // random color from the file
				{
					array<string> colorNames = g_LightColors.getKeys();
					string randomcolor = colorNames[ Math.RandomLong(0, (colorNames.length() - 1)) ];
					pData.vecColor = Vector( g_LightColors[randomcolor] );
				}
				else if( g_LightColors.exists(args.Arg(1).ToLowercase()) )
					pData.vecColor = Vector( g_LightColors[args.Arg(1).ToLowercase()] );
				else
				{
					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, sPrefix + " No such color: \"" + args.Arg(1) + "\" Use " + sCommand + " list to see all available colors.\n" );
					return;
				}
			}
			else if( args.ArgC() == 4 ) // 3 args are supplied (R, G, B)
			{
				if( atoi(args.Arg(1)) >= 0 and atoi(args.Arg(1)) <= 255 and atoi(args.Arg(2)) >= 0 and atoi(args.Arg(2)) <= 255 and atoi(args.Arg(3)) >= 0 and atoi(args.Arg(3)) <= 255 )
					pData.vecColor = Vector( atoi(args.Arg(1)), atoi(args.Arg(2)), atoi(args.Arg(3)) );
				else
				{
					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, sPrefix + " Usage: " + sCommand + " <color/random/randomcolor> or <0-255> <0-255> <0-255>\n" );
					return;
				}
			}
			else
			{
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, sPrefix + " Usage: " + sCommand + " <color/random/randomcolor> or <0-255> <0-255> <0-255>\n" );
				return;
			}

			g_PlayerLights[string(id)] = pData;

			if( pData.bFlashlightOn )
			{
				LightTurnOff( pPlayer, MODE_FLASHLIGHT );

				if( uiMode == MODE_NIGHTVISION and pData.iBattery >= 1 )
					LightTurnOn( pPlayer, uiMode );
			}
			else if( pData.bNightvisionOn )
			{
				LightTurnOff( pPlayer, MODE_NIGHTVISION );

				if( uiMode == MODE_FLASHLIGHT and pData.iBattery >= 1 )
					LightTurnOn( pPlayer, uiMode );
			}
			else if( pData.iBattery >= 1 )
			{
				if( pPlayer.FlashlightIsOn() ) pPlayer.FlashlightTurnOff();

				LightTurnOn( pPlayer, uiMode );
			}
		}
	}
}

void FLNV_Think()
{
	float flTime = g_Engine.time;

	for( int id = 0; id <= g_Engine.maxClients; ++id )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
		if( pPlayer is null ) continue;
		if( !pPlayer.IsConnected() ) continue;
		if( !g_PlayerLights.exists(string(id)) ) continue;

		PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );

		if( g_flDrain.GetFloat() > 0.0f and pData.flLightTime > 0.0f and pData.flLightTime <= flTime )
		{
			if( pData.bFlashlightOn or pData.bNightvisionOn )
			{
				if( pData.iBattery >= 1 )
				{
					if( pPlayer.FlashlightIsOn() ) pPlayer.FlashlightTurnOff();

					pData.flLightTime = flTime + g_flDrain.GetFloat();
					--pData.iBattery;

					if( pData.iBattery <= 0 )
					{
						if( pData.bFlashlightOn )
							LightTurnOff( pPlayer, MODE_FLASHLIGHT );
						else
							LightTurnOff( pPlayer, MODE_NIGHTVISION );
					}
				}
			}
			else
			{
				if( pData.iBattery < 100 )
				{
					pData.flLightTime = flTime + g_flCharge.GetFloat();
					++pData.iBattery;
				}
				else
					pData.flLightTime = 0.0f;
			}

			NetworkMessage flbatt( MSG_ONE_UNRELIABLE, NetworkMessages::FlashBat, pPlayer.edict() );
				flbatt.WriteByte( pData.iBattery );
			flbatt.End();
		}

		g_PlayerLights[string(id)] = pData;

		if( pData.bFlashlightOn )
			LightMsg( pPlayer, MODE_FLASHLIGHT );
		else if( pData.bNightvisionOn )
			LightMsg( pPlayer, MODE_NIGHTVISION );
	}
}

void FLNV_RainbowThink()
{
	for( int i = 1; i <= g_Engine.maxClients; ++i )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
		if( pPlayer is null ) continue;

		int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());

		if( !g_PlayerLights.exists(string(id)) ) continue;

		PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );

		if( pData.bRainbow )
		{
			if( pData.vecRainbowColor.x == 255 and pData.vecRainbowColor.y == 0 and pData.vecRainbowColor.z < 255 )
				pData.vecRainbowColor.z += g_iRainbowIncrement;
			else if( pData.vecRainbowColor.x > 0 and pData.vecRainbowColor.y == 0 and pData.vecRainbowColor.z == 255 )
				pData.vecRainbowColor.x -= g_iRainbowIncrement;
			else if( pData.vecRainbowColor.x == 0 and pData.vecRainbowColor.y < 255 and pData.vecRainbowColor.z == 255 )
				pData.vecRainbowColor.y += g_iRainbowIncrement;
			else if( pData.vecRainbowColor.x == 0 and pData.vecRainbowColor.y == 255 and pData.vecRainbowColor.z > 0 )
				pData.vecRainbowColor.z -= g_iRainbowIncrement;
			else if( pData.vecRainbowColor.x < 255 and pData.vecRainbowColor.y == 255 and pData.vecRainbowColor.z == 0 )
				pData.vecRainbowColor.x += g_iRainbowIncrement;
			else if( pData.vecRainbowColor.x == 255 and pData.vecRainbowColor.y > 0 and pData.vecRainbowColor.z == 0 )
				pData.vecRainbowColor.y -= g_iRainbowIncrement;

			g_PlayerLights[string(id)] = pData;
		}
	}
}

void LightMsg( CBasePlayer@ pPlayer, const LightModes &in uiMode )
{
	if( pPlayer is null ) return;
	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());
	if( !g_PlayerLights.exists(string(id)) ) return;

	PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );

	if( uiMode == MODE_FLASHLIGHT )
	{
		Vector origin = pPlayer.GetGunPosition();
		TraceResult tr;
		Math.MakeVectors(pPlayer.pev.v_angle);
		g_Utility.TraceLine( origin, origin + g_Engine.v_forward * g_flDistanceMax, dont_ignore_monsters, pPlayer.edict(), tr );
		float flDist = (origin - tr.vecEndPos).Length();

		if( flDist > g_flDistanceMax ) return;

		/*float flDecay, flAttn;
		flDecay = flDist * 255 / g_flDistanceMax;
		flAttn = 256 + flDecay * g_iAttenuation;

		//This mumbojumbo decreases the brightness the further away the light is
		int iR = int((int(pData.vecColor.x) << 8 ) / flAttn);
		int iG = int((int(pData.vecColor.y) << 8 ) / flAttn);
		int iB = int((int(pData.vecColor.z) << 8 ) / flAttn);*/

		int iR = int(pData.vecColor.x);
		int iG = int(pData.vecColor.y);
		int iB = int(pData.vecColor.z);

		if( pData.bRainbow )
			pData.vecColor = pData.vecRainbowColor;

		if( g_bShowFlashlightToAll )
		{
			NetworkMessage flon( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
				flon.WriteByte( TE_DLIGHT );
				flon.WriteCoord( tr.vecEndPos.x );
				flon.WriteCoord( tr.vecEndPos.y );
				flon.WriteCoord( tr.vecEndPos.z );
				flon.WriteByte( g_iFlashlightRadius.GetInt() );
				flon.WriteByte( iR );
				flon.WriteByte( iG );
				flon.WriteByte( iB );
				flon.WriteByte( iLife );
				flon.WriteByte( 1 );
			flon.End();
		}
		else
		{
			NetworkMessage flon( MSG_ONE_UNRELIABLE, NetworkMessages::SVC_TEMPENTITY, pPlayer.edict() );
				flon.WriteByte( TE_DLIGHT );
				flon.WriteCoord( tr.vecEndPos.x );
				flon.WriteCoord( tr.vecEndPos.y );
				flon.WriteCoord( tr.vecEndPos.z );
				flon.WriteByte( g_iFlashlightRadius.GetInt() );
				flon.WriteByte( iR );
				flon.WriteByte( iG );
				flon.WriteByte( iB );
				flon.WriteByte( iLife );
				flon.WriteByte( 1 );
			flon.End();
		}
	}
	else
	{
		Vector vecSrc = pPlayer.EyePosition();
		int iR = int(pData.vecColor.x);
		int iG = int(pData.vecColor.y);
		int iB = int(pData.vecColor.z);

		if( pData.bRainbow )
			pData.vecColor = pData.vecRainbowColor;

		NetworkMessage nvon( MSG_ONE, NetworkMessages::SVC_TEMPENTITY, pPlayer.edict() );
			nvon.WriteByte( TE_DLIGHT );
			nvon.WriteCoord( vecSrc.x );
			nvon.WriteCoord( vecSrc.y );
			nvon.WriteCoord( vecSrc.z );
			nvon.WriteByte( g_iNightvisionRadius.GetInt() ); //radius in 10's
			nvon.WriteByte( iR );
			nvon.WriteByte( iG );
			nvon.WriteByte( iB );
			nvon.WriteByte( 2 ); //life in 10's
			nvon.WriteByte( 1 ); //decay rate in 10's
		nvon.End();
	}
}

void LightTurnOn( CBasePlayer@ pPlayer, const uint &in uiMode )
{
	if( pPlayer is null ) return;

	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());

	if( g_PlayerLights.exists(string(id)) )
	{
		PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );

		if( uiMode == MODE_FLASHLIGHT )
		{
			g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_WEAPON, SOUND_FLASHLIGHT_ON, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
			pData.bFlashlightOn = true;
		}
		else
		{
			g_PlayerFuncs.ScreenFade( pPlayer, pData.vecColor, 0.01, 0.5, 64, FFADE_OUT | FFADE_STAYOUT );
			g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_WEAPON, "player/hud_nightvision.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );
			pData.bNightvisionOn = true;
		}

		LightHudDraw( pPlayer, 1 );

		pData.flLightTime = g_Engine.time + g_flDrain.GetFloat();

		g_PlayerLights[string(id)] = pData;
	}
}

void LightTurnOff( CBasePlayer@ pPlayer, const LightModes &in uiMode )
{
	if( pPlayer is null ) return;

	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());

	if( g_PlayerLights.exists(string(id)) )
	{
		PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );

		if( uiMode == MODE_FLASHLIGHT )
		{
			g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_WEAPON, SOUND_FLASHLIGHT_OFF, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
			pData.bFlashlightOn = false;
		}
		else
		{
			g_PlayerFuncs.ScreenFade( pPlayer, pData.vecColor, 0.01f, 0.1f, 64, FFADE_IN );
			g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_WEAPON, "items/flashlight2.wav", 0.8f, ATTN_NORM, 0, PITCH_NORM );
			pData.bNightvisionOn = false;
		}

		pData.bRainbow = false;

		LightHudDraw( pPlayer, 0 );

		pData.flLightTime = g_Engine.time + g_flCharge.GetFloat();

		g_PlayerLights[string(id)] = pData;
	}
}

void LightHudDraw( CBasePlayer@ pPlayer, uint iFlag )
{
	if( pPlayer is null ) return;

	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());

	if( g_PlayerLights.exists(string(id)) )
	{
		PlayerLightData@ pData = cast<PlayerLightData@>( g_PlayerLights[string(id)] );
		
		NetworkMessage fl( MSG_ONE_UNRELIABLE, NetworkMessages::Flashlight, pPlayer.edict() );
			fl.WriteByte( iFlag );
			fl.WriteByte( pData.iBattery );
		fl.End();
	}
}

void LightHelp( CBasePlayer@ pPlayer, const LightModes &in iMode )
{
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "AVAILABLE COMMANDS\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "------------------------\n" );

	switch( iMode )
	{
		case MODE_FLASHLIGHT:
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".flashlight <color> - Toggles the flashlight. Default is white if no color is specified\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".flashlight list - Prints flashlight colors to console\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".flashlight r g b - Toggles the flashlight with custom RGB-values\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".flashlight random - Toggles the flashlight with random RGB\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".flashlight randomcolor - Toggles the flashlight with a random color from the list\n" );
			if( g_PlayerFuncs.AdminLevel( pPlayer ) > ADMIN_NO )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".flashlight rainbow - Toggles the flashlight with shifting colors\n" );

			break;
		}
		case MODE_NIGHTVISION:
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".nightvision <color> - Toggles nightvision. Default is green if no color is specified\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".nightvision list - Prints nightvision colors to console\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".nightvision r g b - Toggles nightvision with custom RGB-values\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".nightvision random - Toggles nightvision with random RGB\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".nightvision randomcolor - Toggles nightvision with a random color from the list\n" );
			if( g_PlayerFuncs.AdminLevel( pPlayer ) > ADMIN_NO )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".nightvision rainbow - Toggles nightvision with shifting colors\n" );

			break;
		}
	}

	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "------------------------\n" );
}

void LightList( CBasePlayer@ pPlayer, const LightModes &in iMode )
{
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "AVAILABLE COLORS\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "------------------------\n" );

	string sMessage = "";

	for( uint i = 1; i < g_ColorListKeys.length()+1; ++i )
	{
		sMessage += g_ColorListKeys[i-1] + " | ";

		if( i % 7 == 0 )
		{
			sMessage.Resize( sMessage.Length() - 2 );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, sMessage );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n" );
			sMessage = "";
		}
	}

	if( sMessage.Length() > 2 )
	{
		sMessage.Resize( sMessage.Length() - 2 );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, sMessage + "\n" );
	}
	
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "------------------------\n" );
}

void LightSettings( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	const string sCommand = args.Arg(0);

	if( args.ArgC() < 2 )//If no args are supplied
	{
		if( sCommand == ".fl_radius" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"fl_radius\" is \"" + g_iFlashlightRadius.GetInt() + "\"\n" );
		else if( sCommand == ".nv_radius" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"nv_radius\" is \"" + g_iNightvisionRadius.GetInt() + "\"\n" );
		else if( sCommand == ".flnv_drain" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"flnv_drain\" is \"" + g_flDrain.GetFloat() + "\"\n" );
		else if( sCommand == ".flnv_charge" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"flnv_charge\" is \"" + g_flCharge.GetFloat() + "\"\n" );
	}
	else if( args.ArgC() == 2 )//If one arg is supplied (value to set)
	{
		if( sCommand == ".fl_radius" and Math.clamp(1, 255, atoi(args.Arg(1))) != g_iFlashlightRadius.GetInt() )
		{
			g_iFlashlightRadius.SetInt( Math.clamp(1, 255, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"fl_radius\" changed to \"" + g_iFlashlightRadius.GetInt() + "\"\n" );
		}
		else if( sCommand == ".nv_radius" and Math.clamp(1, 255, atoi(args.Arg(1))) != g_iNightvisionRadius.GetInt() )
		{
			g_iNightvisionRadius.SetInt( Math.clamp(1, 255, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"nv_radius\" changed to \"" + g_iNightvisionRadius.GetFloat() + "\"\n" );
		}
		else if( sCommand == ".flnv_drain" and atof(args.Arg(1)) != g_flDrain.GetFloat() )
		{
			g_flDrain.SetFloat( atof(args.Arg(1)) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"flnv_drain\" changed to \"" + g_flDrain.GetFloat() + "\"\n" );
		}
		else if( sCommand == ".flnv_charge" and atof(args.Arg(1)) != g_flCharge.GetFloat() )
		{
			g_flCharge.SetFloat( atof(args.Arg(1)) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"flnv_charge\" changed to \"" + g_flCharge.GetFloat() + "\"\n" );
		}
	}
}
} //end of namespace CustomLights

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		November 18 2017
*	-------------------------
*	- First release
*	-------------------------
*
*	Version: 	1.1
*	Date: 		December 03 2017
*	-------------------------
*	- Flashlight and Nightvision is not turned off when a player is killed
*	-------------------------
*
*	Version: 	1.1.1
*	Date: 		January 27 2018
*	-------------------------
*	- Rainbow color is no longer admin-only for nightvision
*	-------------------------
*/
/*
*	ToDo
*
*/