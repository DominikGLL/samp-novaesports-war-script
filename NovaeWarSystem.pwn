#include <a_samp>
#include <streamer>
#include <zcmd>
#include <a_mysql>
#include <sscanf2>
/*
- Nova-eWar Script (Rebellen gegen Bundeswehr)
INFO: FraktionsID 1 = Bundeswehr
	  FraktionsID 2 = Rebellen
Befehle: /ewar [anfrage/annehmen/ablehnen] -> Antrag an die andere Fraktion stellen
		 /ewarstats -> Einsicht in die persönliche Statistik
		 /ewarhelp -> Einsicht aller Befehle
		 /stopewar -> Adminbefehl zum stoppen vom Nova-eWar
		 /resetwar -> Adminbefehl um den Nova-eWar zu stoppen und einen Neustart zu ermöglichen
		 /setnovaewar [aktvieren/deaktivieren] -> Adminbefehl um den Nova-eWar zu aktivieren und deaktivieren
*/
/*MySQL-Tabellen*/
/*
--
-- Tabellenstruktur für Tabelle `novaewar`
--

CREATE TABLE IF NOT EXISTS `novaewar` (
  `ID` int(8) NOT NULL,
  `ActiveWar` int(8) NOT NULL,
  `WarStarted` int(8) NOT NULL,
  `RebelsCounter` int(8) NOT NULL,
  `MilitaryCounter` int(8) NOT NULL,
  `WarTime` int(8) NOT NULL,
  `WarZoneRebelSteps` int(8) NOT NULL,
  `WarZoneMilitarySteps` int(8) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `novaewarstats`
--

CREATE TABLE IF NOT EXISTS `novaewarstats` (
`ID` int(8) NOT NULL AUTO_INCREMENT=1,
  `LastWinner` int(8) NOT NULL,
  `LastMatch` int(8) NOT NULL,
  `LastRebelsCounter` int(8) NOT NULL,
  `LastMilitaryCounter` int(8) NOT NULL,
  PRIMARY KEY (`ID`);
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
*/
//Makros für spezifische pVars -> müssen im Gamemode angepasst werden
#define GetPlayerWarKills(%0) GetPVarInt(%0, "eWarKills")
#define GetPlayerWarDeaths(%0) GetPVarInt(%0, "eWarDeaths")
#define GetPlayerWarStreak(%0) GetPVarInt(%0, "eWarStreak")
#define AddPlayerWarKill(%0) SetPVarInt(%0, "eWarKills", (GetPlayerWarKills(%0)+1))
#define AddPlayerStreakKill(%0) SetPVarInt(%0, "eWarStreak", (GetPlayerWarStreak(%0)+1))
#define AddPlayerWarDeath(%0) SetPVarInt(%0, "eWarDeaths", (GetPlayerWarDeaths(%0)+1))
#define RemovePlayerWarStreak(%0) SetPVarInt(%0, "eWarStreak",0)
#define DestroyVars(%0) DeletePVar(%0, "eWarKills"),DeletePVar(%0, "eWarStreak"),DeletePVar(%0, "eWarDeaths")

#define SCM(%0,%1,%2) SendClientMessage(%0,%1,%2)
#define GetPlayerFraktion(%0) GetPVarInt(%0, "Fraktion")
#define GetPlayerRang(%0) GetPVarInt(%0, "Rang")
#define GetPlayerAdmin(%0) GetPVarInt(%0, "Admin")
#define ErrorMSG(%0,%1) SendClientMessage(%0,-1,%1)
#define GetName(%0) PlayerName[%0]

#define GetPlayerStreakSlot1(%0) GetPVarInt(%0, "eWarStreakSlot1")
#define GetPlayerStreakSlot2(%0) GetPVarInt(%0, "eWarStreakSlot2")
#define GetPlayerStreakSlot3(%0) GetPVarInt(%0, "eWarStreakSlot3")
#define RemovePlayerStreak1(%0) SetPVarInt(%0, "eWarStreakSlot1", 0)
#define RemovePlayerStreak2(%0) SetPVarInt(%0, "eWarStreakSlot2", 0)
#define RemovePlayerStreak3(%0) SetPVarInt(%0, "eWarStreakSlot3", 0)
#define SetPlayerStreakSlot1(%0,%1) SetPVarInt(%0, "eWarStreakSlot1", %1)
#define SetPlayerStreakSlot2(%0,%1) SetPVarInt(%0, "eWarStreakSlot2", %1)
#define SetPlayerStreakSlot3(%0,%1) SetPVarInt(%0, "eWarStreakSlot3", %1)

forward OnWarSystemUpdate1();
forward OnWarSystemUpdate2();

enum WarInfo_daten
{
	ActiveWar,//Aktivierung / Deaktivierung des Nova-eWar System (administrativ)
	WarStarted,//Nova-eWar Variable zur Prüfung, ob ein War stattfindet
	RebelsCounter,//Zähler Rebellen
	MilitaryCounter,//Zähler Bundeswehr
	WarTime,//Zeit in Minuten
	WarZoneRebelSteps,WarZoneMilitarySteps,//In welcher Zone, welches Team gerade kämpft
	SprengsatzRebelsFS[2],SprengsatzRebelsFSTime[2],//Rebellen Funkstation State + Time
	SprengsatzObjRebel[2],SprengsatzObjMilitary[2],//Bomben/SprengsatzObject
	SprengsatzMilitaryFS[2],SprengsatzMilitaryFSTime[2],//Bundeswehr Funkstation State + Time
	WarRebelsBlockPlant,WarMilitaryBlockPlant,//Blockierung vom Platzierungsbefehl
	LastWinner,LastMatch,LastRebelsCounter,LastMilitaryCounter,//Letzter Gewinner, Letztes Match
	KillStreakPlayerIDMilitary,KillStreakVehMilitary,KillStreakMilitaryTime,//KillstreaksPlayerid,FahrzeugID,KillstreakZeit
	KillStreakPlayerIDRebels,KillStreakRebelsTime,KillStreakVehRebels,//KillstreaksPlayerid,FahrzeugID,KillstreakZeit
	FunkstationMapIconRebels[2],FunkstationMapIconMilitary[2],//Funkstation Mapicon Rebellen - Bundeswehr
	MilitaryZerstoert[2],RebelsZerstoert[2],//Funkstationen zerstört State Rebellen - Bundeswehr
	BombenLegerMilitary[2],BombenLegerRebels[2],//Bombenleger State - Bundeswehr / Rebellen
	BombenLegerIDMilitary[2],BombenLegerIDRebels[2],//Bombenleger ID - Bundeswehr / Rebellen
	BombenDefuseMilitary[2],BombenDefuseRebels[2],//Bombenleger Time - Bundeswehr /Rebellen
	BombenDefuseIDRebels[2],BombenDefuseIDMilitary[2],//Bombenleger ID - Bundeswehr / Rebellen
	RebelVehID[4],MilitaryVehID[4],//FahrzeugeVar Rebellen / Bundeswehr
}
new WarInfo[WarInfo_daten];

enum WarZones
{
	WarZoneID,
	WarZoneName[32],
    Float:WarZoneMinX,
	Float:WarZoneMinY,
	Float:WarZoneMaxX,
	Float:WarZoneMaxY,
	Float:FunkStation1[6],
	Float:FunkStation2[6],
	Float:HQSpawn[3],
	Float:veh1[4],Float:veh2[4],Float:veh3[4],Float:veh4[4],
	FunktstationObject1[6],
	FunktstationObject2[6],
	Text3D:ObjectLabel1[6],
	Text3D:ObjectLabel2[6],
};
new RebelZones[3][WarZones] = {
{-1,"El Quebrados", -1634.903, 2487.387, -1319.6, 2755.979,{-1476.927,2628.874,57.781,0.000,0.000,0.000},{-1516.759,2567.611,54.835,0.000,0.000,-87.800},{-1266.1920,2716.7505,50.2663},{-1267.4224,2710.5313,49.7754,208.9699},{-1272.9120,2707.1340,49.7713,208.3787},{-1258.9890,2715.4246,49.6245,209.0499},{-1249.0283,2706.7114,50.2397,120.9122}},
{-1,"Valle Ocultado", -1074.365, 2580.811, -642.2831, 2826.046,{-733.313,2754.694,46.226,0.000,0.000,-91.199},{-904.408,2686.133,41.370,0.000,0.000,-134.399},{-604.7368,2716.9360,72.7231},{-595.2638,2718.9358,71.9785,179.8819},{-616.2324,2714.8879,71.9803,182.8260},{-608.3068,2716.5227,71.8552,179.9693},{-629.8476,2715.7866,72.4481,176.8286}},
{-1,"Las Payasdas", -432.0814, 2545.777, -11.67788, 2814.368,{-278.493,2654.058,61.607,0.000,0.000,-94.099},{-219.727,2724.959,61.687,0.000,0.000,-88.099},{-95.3536,2798.2959,78.3194},{-90.7761,2807.6101,77.1802,176.5857},{-92.5555,2792.6262,76.5797,172.1082},{-98.0160,2804.7263,78.4709,81.2619},{-78.6723,2812.6758,75.6303,134.0041}}
};
new MilitaryZones[3][WarZones] = {
{-1,"Tierra Robada",-1553.157, 1763.359, -1097.72, 2090.34,{-1513.639,1974.476,47.417,0.000,0.000,178.500},{-1359.287,2052.388,51.515,0.000,0.000,88.299},{-1213.5748,1823.5763,41.7188},{-1206.5577,1810.7340,41.4234,43.4600},{-1201.0609,1815.0792,41.4240,45.4021},{-1196.3716,1819.8350,41.2889,45.4940},{-1196.5065,1830.1685,41.8960,45.0053}},
{-1,"Las Barrancas",-960.6848,1402.1820,-611.3416,1654.9606,{-795.162,1519.681,25.862,0.000,0.000,90.599},{-735.195,1547.716,37.995,0.000,0.000,177.300},{-687.7134,946.7305,13.0313},{-694.1119,947.1907,11.9506,0.5706},{-697.9772,946.9827,12.0111,0.9860},{-701.9078,945.5291,11.9420,6.8125},{-711.9496,967.0843,12.5177,0.1778}},
{-1,"Fort Carson",-384.9832,1005.2629,111.4191,1243.0842,{-107.408,1133.475,18.742,0.000,0.000,0.000},{-211.104,1074.184,18.742,0.000,0.000,-89.800},{-92.5927,1363.6201,10.2734},{-88.3822,1339.2838,10.3688,7.2639},{-94.7363,1338.5897,10.1514,8.0614},{-82.3968,1339.1508,10.4915,6.6666},{-4.8681,1364.9746,9.3485,101.2356}}
};
new stunde, minute, sekunde, jahr, monat, tag,
	MySQL,
    eWarAnfrage[4],
	PlayerName[MAX_PLAYERS][MAX_PLAYER_NAME],
	Float:PlayerWarPos[MAX_PLAYERS][4];
	
enum
{
    _SQL_LOAD_EWAR,
    _SQL_LOAD_EWARSTATS,
}

//Funktion: Zufälllige FunktstationsobjektID
stock GetRandomFunkstationID()
{
	new oid = random(4);
	switch(oid)
	{
		case 0:oid=3386;
		case 1:oid=3388;
		case 2:oid=3387;
		case 3:oid=3389;
	}
	return oid;
}
//Funktion: Rangabfrage -> playerid, rang
stock isPlayerAMember(playerid,rang)
{
	if(GetPlayerRang(playerid) >= rang)return 1;
	return 0;
}
//Funktion: Kriegszonen werden angezeigt -> playerid
stock ShowPlayerKriegszone(playerid)
{
	new i;
    for(i=0; i<3; i++)
    {
    	GangZoneShowForPlayer(playerid, RebelZones[i][WarZoneID], 0x80400085);
    	GangZoneShowForPlayer(playerid, MilitaryZones[i][WarZoneID], 0x056C0096);
	}
	if(WarInfo[WarStarted] == 1 && WarInfo[WarTime] != 0)
	{
	    if(WarInfo[WarTime] <= 120)
	    {
	        GangZoneFlashForAll(RebelZones[WarInfo[WarZoneRebelSteps]][WarZoneID], 0x056C0096);
	        GangZoneFlashForAll(MilitaryZones[WarInfo[WarZoneMilitarySteps]][WarZoneID], 0x80400085);
	        if(WarInfo[WarZoneRebelSteps] == 1)GangZoneHideForPlayer(playerid, RebelZones[0][WarZoneID]);
	        else if(WarInfo[WarZoneRebelSteps] == 2)GangZoneHideForPlayer(playerid, RebelZones[0][WarZoneID]);GangZoneHideForPlayer(playerid, RebelZones[1][WarZoneID]);
	        if(WarInfo[WarZoneMilitarySteps] == 1)GangZoneHideForPlayer(playerid, MilitaryZones[0][WarZoneID]);
	        else if(WarInfo[WarZoneMilitarySteps] == 2)GangZoneHideForPlayer(playerid, MilitaryZones[0][WarZoneID]);GangZoneHideForPlayer(playerid, MilitaryZones[1][WarZoneID]);
	    }
	}
	return 1;
}
//Funktion: Initialisierung der Zonen
stock InitializeWarSystem()
{
	new i,o,query[128];
	for(i=0; i<3; i++)
	{
        RebelZones[i][WarZoneID] = GangZoneCreate(RebelZones[i][WarZoneMinX],RebelZones[i][WarZoneMinY],RebelZones[i][WarZoneMaxX],RebelZones[i][WarZoneMaxY]);
        for(o=0; o<6; o++)
        {
            RebelZones[i][FunktstationObject1][o] = CreateObject(GetRandomFunkstationID(),RebelZones[i][FunkStation1][0],RebelZones[i][FunkStation1][1],RebelZones[i][FunkStation1][2],RebelZones[i][FunkStation1][3],RebelZones[i][FunkStation1][4],RebelZones[i][FunkStation1][5]);
            RebelZones[i][FunktstationObject2][o] = CreateObject(GetRandomFunkstationID(),RebelZones[i][FunkStation2][0],RebelZones[i][FunkStation2][1],RebelZones[i][FunkStation2][2],RebelZones[i][FunkStation2][3],RebelZones[i][FunkStation2][4],RebelZones[i][FunkStation2][5]);
            RebelZones[i][ObjectLabel1][o] = Create3DTextLabel("Funkstation der Rebellen\n\nSprengsatz platzieren: Taste N\n\nSprengsatz entschärfen Taste Z", 0x80400085, RebelZones[i][FunkStation1][0],RebelZones[i][FunkStation1][1],RebelZones[i][FunkStation1][2]+3.5, 10.0, 0, 0);
            RebelZones[i][ObjectLabel2][o] = Create3DTextLabel("Funkstation der Rebellen\n\nSprengsatz platzieren: Taste N\n\nSprengsatz entschärfen Taste Z", 0x80400085, RebelZones[i][FunkStation2][0],RebelZones[i][FunkStation2][1],RebelZones[i][FunkStation2][2]+3.5, 10.0, 0, 0);
		}
	}
	for(i=0; i<3; i++)
	{
	    MilitaryZones[i][WarZoneID] = GangZoneCreate(MilitaryZones[i][WarZoneMinX],MilitaryZones[i][WarZoneMinY],MilitaryZones[i][WarZoneMaxX],MilitaryZones[i][WarZoneMaxY]);
        for(o=0; o<6; o++)
        {
            MilitaryZones[i][FunktstationObject1][o] = CreateObject(GetRandomFunkstationID(),MilitaryZones[i][FunkStation1][0],MilitaryZones[i][FunkStation1][1],MilitaryZones[i][FunkStation1][2],MilitaryZones[i][FunkStation1][3],MilitaryZones[i][FunkStation1][4],MilitaryZones[i][FunkStation1][5]);
            MilitaryZones[i][FunktstationObject2][o] = CreateObject(GetRandomFunkstationID(),MilitaryZones[i][FunkStation2][0],MilitaryZones[i][FunkStation2][1],MilitaryZones[i][FunkStation2][2],MilitaryZones[i][FunkStation2][3],MilitaryZones[i][FunkStation2][4],MilitaryZones[i][FunkStation2][5]);
            MilitaryZones[i][ObjectLabel1][o] = Create3DTextLabel("Funkstation der Bundeswehr\n\nSprengsatz platzieren: Taste N\n\nSprengsatz entschärfen Taste Z", 0x056C0096, MilitaryZones[i][FunkStation1][0],MilitaryZones[i][FunkStation1][1],MilitaryZones[i][FunkStation1][2]+3.5, 10.0, 0, 0);
            MilitaryZones[i][ObjectLabel2][o] = Create3DTextLabel("Funkstation der Bundeswehr\n\nSprengsatz platzieren: Taste N\n\nSprengsatz entschärfen Taste Z", 0x056C0096, MilitaryZones[i][FunkStation2][0],MilitaryZones[i][FunkStation2][1],MilitaryZones[i][FunkStation2][2]+3.5, 10.0, 0, 0);
		}
	}
	eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID, eWarAnfrage[3] = -1;
	WarInfo[WarZoneRebelSteps] = 0, WarInfo[WarZoneMilitarySteps] = 0;
	WarInfo[ActiveWar] = 1;
	WarInfo[WarStarted] = 0, WarInfo[WarTime] = 0;
	for(new p;p<2;p++)WarInfo[BombenLegerIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenLegerIDRebels][p] = INVALID_PLAYER_ID;
	for(new p;p<2;p++)WarInfo[BombenDefuseIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenDefuseIDRebels][p] = INVALID_PLAYER_ID;
	for(new p;p<2;p++)WarInfo[RebelsZerstoert][p] = 0, WarInfo[MilitaryZerstoert][p] = 0;
	WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID,WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
	CreatePickup(342,1,268.6505,1883.3195,-30.0938);//Bundeswehr
	CreatePickup(342,1,-1851.8097,-1699.4791,40.8672);//Rebellen
	Create3DTextLabel("Nova-eWars Portpunkt",0x056C0096,268.6505,1883.3195,-30.0938+1.0,10.0, 0, 1);//Bundeswehr
	Create3DTextLabel("Nova-eWars Portpunkt",0x80400085,-1851.8097,-1699.4791,40.8672+1.0,10.0, 0, 1);//Rebellen
	SetTimer("OnWarSystemUpdate1",1000,1);
	SetTimer("OnWarSystemUpdate2",60000,1);
	mysql_format(MySQL, query, sizeof(query),"SELECT * FROM `novaewar` WHERE ID='1' LIMIT 1");
	mysql_tquery(MySQL, query,"OnQueryFinish","siii",query,_SQL_LOAD_EWAR,0,MySQL);
	mysql_format(MySQL, query, sizeof(query),"SELECT * FROM `novaewarstats` ORDER BY ID DESC LIMIT 1");
	mysql_tquery(MySQL, query,"OnQueryFinish","siii",query,_SQL_LOAD_EWARSTATS,0,MySQL);
	return print("Warsystem geladen!");
}

stock UpdateNovaWar()
{
	new query[128];
	mysql_format(MySQL, query, sizeof(query), "UPDATE `novaewar` SET ActiveWar='%i', WarStarted='%i', RebelsCounter='%i', MilitaryCounter='%i', WarTime='%i', WarZoneRebelSteps='%i', WarZoneMilitarySteps='%i' WHERE ID='1'",
	WarInfo[ActiveWar],WarInfo[WarStarted],WarInfo[RebelsCounter],WarInfo[MilitaryCounter],WarInfo[WarTime],WarInfo[WarZoneRebelSteps],WarInfo[WarZoneMilitarySteps]);
	mysql_query(MySQL, query, false);
	return 1;
}

//Funktion: OnQueryFinish(index[],sqlresultid,extraid,SconnectionHandle)
forward OnQueryFinish(index[],sqlresultid,extraid,SconnectionHandle);
public OnQueryFinish(index[],sqlresultid,extraid,SconnectionHandle)
{
	new result[64],rows,fields;
	switch(sqlresultid)
	{
	    case _SQL_LOAD_EWAR:
	    {
	        cache_get_data(rows,fields);
	        if(rows)
			{
			    cache_get_field_content(0,"ActiveWar",result);
				WarInfo[ActiveWar] = strval(result);
				strdel(result,0,sizeof(result));
                cache_get_field_content(0,"WarStarted",result);
				WarInfo[WarStarted] = strval(result);
				strdel(result,0,sizeof(result));
				cache_get_field_content(0,"RebelsCounter",result);
				WarInfo[RebelsCounter] = strval(result);
				strdel(result,0,sizeof(result));
				cache_get_field_content(0,"MilitaryCounter",result);
				WarInfo[MilitaryCounter] = strval(result);
				strdel(result,0,sizeof(result));
				cache_get_field_content(0,"WarTime",result);
				WarInfo[WarTime] = strval(result);
				strdel(result,0,sizeof(result));
				cache_get_field_content(0,"WarZoneRebelSteps",result);
				WarInfo[WarZoneRebelSteps] = strval(result);
				strdel(result,0,sizeof(result));
				cache_get_field_content(0,"WarZoneMilitarySteps",result);
				WarInfo[WarZoneMilitarySteps] = strval(result);
				strdel(result,0,sizeof(result));
			}
			else
			{
		    	mysql_query(MySQL,"INSERT INTO `novaewar` (ID,ActiveWar,WarStarted,RebelsCounter,MilitaryCounter,WarTime,WarZoneRebelSteps,WarZoneMilitarySteps) VALUES ('1','0','0','0','0','0','0','0')",false);
			}
			return 1;
		}
		case _SQL_LOAD_EWARSTATS:
		{
		    cache_get_data(rows,fields);
	        if(rows)
			{
			    cache_get_field_content(0,"LastWinner",result);
				WarInfo[LastWinner] = strval(result);
				strdel(result,0,sizeof(result));
                cache_get_field_content(0,"LastMatch",result);
				WarInfo[LastMatch] = strval(result);
				strdel(result,0,sizeof(result));
				cache_get_field_content(0,"LastRebelsCounter",result);
				WarInfo[LastRebelsCounter] = strval(result);
				strdel(result,0,sizeof(result));
				cache_get_field_content(0,"LastMilitaryCounter",result);
				WarInfo[LastMilitaryCounter] = strval(result);
				strdel(result,0,sizeof(result));
			}
		    return 1;
		}
	}
	return 1;
}

//Funktion: Gibt den aktuellen Tag zurück
stock Day()
{
	new DayOfWeek = ((floatround(jahr * 365.25) - 620628) % 7 -1),NameOfDay[15];
	switch(DayOfWeek)
	{
	    case 0: NameOfDay="Sonntag";
	    case 1: NameOfDay="Montag";
		case 2: NameOfDay="Dienstag";
		case 3: NameOfDay="Mittwoch";
		case 4: NameOfDay="Donnerstag";
		case 5: NameOfDay="Freitag";
		case 6: NameOfDay="Samstag";
		default: NameOfDay="ERROR";
	}
	return NameOfDay;
}
//Funktion: Gibt den Streaknamen zurück
stock GetKillStreakByID(killStreakID)
{
	new killstring[30];
	switch(killStreakID)
	{
	  	case 1:killstring="30 Schuss Country Rifle"; //3er Abschuss
	   	case 2:killstring="5 Handgranaten"; //5er Abschuss
	    case 3:killstring="30 Schuss Sniper Rifle";//7er Abschuss
	    case 4:killstring="30 Sekunden Seasparrow";//9er Abschuss
	    case 5:killstring="3 Schuss RPG";//11er Abschuss
	    case 6:killstring="60 Sekunden Seasparrow";//13er Abschuss
	    case 7:killstring="30 Sekunden Hunter";//15er Abschuss
	    case 8:killstring="3 Schuss HS Rocket";//17er Abschuss
	    case 9:killstring="60 Sekunden Hunter";//19er Abschuss
	    case 10:killstring="50 Schuss Minigun";//21er Abschuss
	 }
	return killstring;
}

public OnWarSystemUpdate1()
{
	if(WarInfo[WarStarted] == 1 && WarInfo[WarTime] != 0)
	{
	    if(WarInfo[WarTime] <= 120)
	    {
			new query[128],string[128];
			for(new i=0;i<2;i++)
			{
				if(WarInfo[BombenDefuseIDRebels][i] != INVALID_PLAYER_ID)
				{
				    new Float:ObjPos[3];
				    GetObjectPos(WarInfo[SprengsatzObjRebel][i],ObjPos[0], ObjPos[1], ObjPos[2]);
				    if(!IsPlayerInRangeOfPoint(WarInfo[BombenDefuseIDRebels][i], 2.0,ObjPos[0], ObjPos[1], ObjPos[2]))
				    {
				        SCM(WarInfo[BombenDefuseIDRebels][i],-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast dich von dem Sprengsatz entfernt. Der Vorgang wurde abgebrochen.");
				        ClearAnimations(WarInfo[BombenDefuseIDRebels][i]);
				        WarInfo[BombenDefuseIDRebels][i] = INVALID_PLAYER_ID;
				    	WarInfo[BombenDefuseRebels][i] = 0;
				    	WarInfo[SprengsatzRebelsFS][i] = 0;
				        WarInfo[SprengsatzRebelsFSTime][i] = 0;
					}
					else
					{
		                if(WarInfo[BombenDefuseRebels][i] < gettime())
						{
						    format(string, sizeof(string),"{2ECCFA}INFO: {FFFFFF}Ein Sprengsatz wurde von %s entschärft. [Funkstation: %i].",GetName(WarInfo[BombenDefuseIDRebels][i]),i+1);
						    for(new playerid;playerid<MAX_PLAYERS;playerid++)if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)SCM(playerid,-1,string);
						    ClearAnimations(WarInfo[BombenDefuseIDRebels][i]);
						    DestroyObject(WarInfo[SprengsatzObjRebel][i]);
						    WarInfo[BombenDefuseIDRebels][i] = INVALID_PLAYER_ID;
						    WarInfo[BombenDefuseRebels][i] = 0;
						}
					}
				}
				if(WarInfo[BombenDefuseIDMilitary][i] != INVALID_PLAYER_ID)
				{
				    new Float:ObjPos[3];
				    GetObjectPos(WarInfo[SprengsatzObjMilitary][i],ObjPos[0], ObjPos[1], ObjPos[2]);
				    if(!IsPlayerInRangeOfPoint(WarInfo[BombenDefuseIDMilitary][i], 2.0,ObjPos[0], ObjPos[1], ObjPos[2]))
				    {
				        SCM(WarInfo[BombenDefuseIDMilitary][i],-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast dich von dem Sprengsatz entfernt. Der Vorgang wurde abgebrochen.");
				        ClearAnimations(WarInfo[BombenDefuseIDMilitary][i]);
				        WarInfo[BombenDefuseIDMilitary][i] = INVALID_PLAYER_ID;
				    	WarInfo[BombenDefuseMilitary][i] = 0;
					}
					else
					{
		                if(WarInfo[BombenDefuseMilitary][i] < gettime())
						{
						    format(string, sizeof(string),"{2ECCFA}INFO: {FFFFFF}Ein Sprengsatz wurde von %s entschärft. [Funkstation: %i].",GetName(WarInfo[BombenDefuseIDMilitary][i]),i+1);
						    for(new playerid;playerid<MAX_PLAYERS;playerid++)if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)SCM(playerid,-1,string);
						    ClearAnimations(WarInfo[BombenDefuseIDMilitary][i]);
						    DestroyObject(WarInfo[SprengsatzObjMilitary][i]);
						    WarInfo[BombenDefuseIDMilitary][i] = INVALID_PLAYER_ID;
						    WarInfo[BombenDefuseMilitary][i] = 0;
						    WarInfo[SprengsatzMilitaryFS][i] = 0;
		                	WarInfo[SprengsatzMilitaryFSTime][i] = 0;
						}
					}
				}
				if(WarInfo[BombenLegerIDMilitary][i] != INVALID_PLAYER_ID)
				{
				    if(!IsPlayerInRangeOfPoint(WarInfo[BombenLegerIDMilitary][i], 2.0,PlayerWarPos[WarInfo[BombenLegerIDMilitary][i]][0], PlayerWarPos[WarInfo[BombenLegerIDMilitary][i]][1], PlayerWarPos[WarInfo[BombenLegerIDMilitary][i]][2]))
				    {
				        SCM(WarInfo[BombenLegerIDMilitary][i],-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast dich von der Funkstation entfernt. Der Vorgang wurde abgebrochen.");
				        ClearAnimations(WarInfo[BombenLegerIDMilitary][i]);
				        WarInfo[BombenLegerIDMilitary][i] = INVALID_PLAYER_ID;
				    	WarInfo[BombenLegerMilitary][i] = 0;
					}
					else
					{
		                if(WarInfo[BombenLegerMilitary][i] < gettime())
						{
						    format(string, sizeof(string),"{2ECCFA}INFO: {FFFFFF}Ein Sprengsatz wurde von %s bei der Bundeswehr platziert [Funkstation: %i]. Sprengung in 5 Minuten!",GetName(WarInfo[BombenLegerIDMilitary][i]),i+1);
						    for(new playerid;playerid<MAX_PLAYERS;playerid++)if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)SCM(playerid,-1,string);
						    ClearAnimations(WarInfo[BombenLegerIDMilitary][i]);
						    WarInfo[SprengsatzObjMilitary][i] = CreateObject(1654,PlayerWarPos[WarInfo[BombenLegerIDMilitary][i]][0], PlayerWarPos[WarInfo[BombenLegerIDMilitary][i]][1], PlayerWarPos[WarInfo[BombenLegerIDMilitary][i]][2]-0.7,-114.199,-90.099,86.400);
						    WarInfo[BombenLegerIDMilitary][i] = INVALID_PLAYER_ID;
						    WarInfo[BombenLegerMilitary][i] = 0;
						    WarInfo[SprengsatzMilitaryFS][i] = 1;
							WarInfo[SprengsatzMilitaryFSTime][i] = gettime() + (5*60);
						}
					}
				}
				if(WarInfo[BombenLegerIDRebels][i] != INVALID_PLAYER_ID)
				{
				    if(!IsPlayerInRangeOfPoint(WarInfo[BombenLegerIDRebels][i], 2.0,PlayerWarPos[WarInfo[BombenLegerIDRebels][i]][0], PlayerWarPos[WarInfo[BombenLegerIDRebels][i]][1], PlayerWarPos[WarInfo[BombenLegerIDRebels][i]][2]))
				    {
				        SCM(WarInfo[BombenLegerIDRebels][i],-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast dich von der Funkstation entfernt. Der Vorgang wurde abgebrochen.");
				        ClearAnimations(WarInfo[BombenLegerIDRebels][i]);
				        WarInfo[BombenLegerIDRebels][i] = INVALID_PLAYER_ID;
				    	WarInfo[BombenLegerRebels][i] = 0;
					}
					else
					{
						if(WarInfo[BombenLegerRebels][i] < gettime())
						{
						    format(string, sizeof(string),"{2ECCFA}INFO: {FFFFFF}Ein Sprengsatz wurde von %s bei den Rebellen platziert [Funkstation: %i]. Sprengung in 5 Minuten!",GetName(WarInfo[BombenLegerIDRebels][i]),i+1);
						    for(new playerid;playerid<MAX_PLAYERS;playerid++)if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)SCM(playerid,-1,string);
						    ClearAnimations(WarInfo[BombenLegerIDRebels][i]);
						    WarInfo[SprengsatzObjRebel][i] = CreateObject(1654,PlayerWarPos[WarInfo[BombenLegerIDRebels][i]][0], PlayerWarPos[WarInfo[BombenLegerIDRebels][i]][1], PlayerWarPos[WarInfo[BombenLegerIDRebels][i]][2]-0.7,-114.199,-90.099,86.400);
                            WarInfo[BombenLegerIDRebels][i] = INVALID_PLAYER_ID;
						    WarInfo[BombenLegerRebels][i] = 0;
						    WarInfo[SprengsatzRebelsFS][i] = 1;
							WarInfo[SprengsatzRebelsFSTime][i] = gettime() + (5*60);
						}
					}
				}
				if(WarInfo[SprengsatzRebelsFS][i] != 0)
				{
				    if(WarInfo[SprengsatzRebelsFSTime][i] < gettime())
				    {
				        WarInfo[SprengsatzRebelsFS][i] = 0;
				        WarInfo[SprengsatzRebelsFSTime][i] = 0;
						switch(i)
						{
						    case 0:CreateExplosion(RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][2], 7,15);
						    case 1:CreateExplosion(RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][2], 7,15);
						}

		                WarInfo[RebelsZerstoert][i] = 1;
		                format(string, sizeof(string),"{2ECCFA}INFO: {FFFFFF}Funkstation %i wurde zerstört!",i+1);
						for(new playerid;playerid<MAX_PLAYERS;playerid++)if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)SCM(playerid,-1,string);
		                if(IsValidDynamicMapIcon(WarInfo[FunkstationMapIconRebels][i]))DestroyDynamicMapIcon(WarInfo[FunkstationMapIconRebels][i]);
		                if(IsValidObject(WarInfo[SprengsatzObjMilitary][i]))DestroyObject(WarInfo[SprengsatzObjRebel][i]);
		                if(WarInfo[RebelsZerstoert][0] == 1 && WarInfo[RebelsZerstoert][1] == 1 && WarInfo[WarZoneRebelSteps] == (sizeof(RebelZones)-1))
					 	{
					 	    WarInfo[WarStarted] = 0;
							WarInfo[WarTime] = 0;
							WarInfo[LastWinner] = -1;
							WarInfo[LastRebelsCounter] = WarInfo[RebelsCounter];
							WarInfo[LastMilitaryCounter] = WarInfo[MilitaryCounter];
							WarInfo[LastMatch] = gettime();
							mysql_format(MySQL,query,sizeof(query),"INSERT INTO `novaewarstats` (LastWinner,LastMatch,LastRebelsCounter,LastMilitaryCounter) VALUES ('%i','%i','%i','%i')",WarInfo[LastWinner],WarInfo[LastMatch],WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
							mysql_query(MySQL,query,false);
							eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
							WarInfo[MilitaryCounter] = 0, WarInfo[RebelsCounter] = 0;
							WarInfo[WarZoneRebelSteps] = 0, WarInfo[WarZoneMilitarySteps] = 0;
							for(new p;p<2;p++)WarInfo[BombenLegerIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenLegerIDRebels][p] = INVALID_PLAYER_ID;
							for(new p;p<2;p++)WarInfo[BombenDefuseIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenDefuseIDRebels][p] = INVALID_PLAYER_ID;
							WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID,WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
							for(new p;p<2;p++)WarInfo[RebelsZerstoert][p] = 0, WarInfo[MilitaryZerstoert][p] = 0;
							DestroyNovaeWarVehicles();
					 	}
		                if(WarInfo[RebelsZerstoert][0] == 1 && WarInfo[RebelsZerstoert][1] == 1)
		                {
		                    GangZoneStopFlashForAll(RebelZones[WarInfo[WarZoneRebelSteps]][WarZoneID]);
		                    GangZoneHideForAll(RebelZones[WarInfo[WarZoneRebelSteps]][WarZoneID]);
		                    WarInfo[WarZoneRebelSteps]++;
		                    GangZoneFlashForAll(RebelZones[WarInfo[WarZoneRebelSteps]][WarZoneID], 0x056C0096);
		                    SetVehicleNovaeWarSpawn(2);
		                    WarInfo[FunkstationMapIconRebels][0] = CreateDynamicMapIcon(RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][2], 20, 0);
							WarInfo[FunkstationMapIconRebels][1] = CreateDynamicMapIcon(RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][2], 20, 0);
						}
					}
				}
				if(WarInfo[SprengsatzMilitaryFS][i] != 0)
				{
				    if(WarInfo[SprengsatzMilitaryFSTime][i] < gettime())
				    {
		                WarInfo[SprengsatzMilitaryFS][i] = 0;
		                WarInfo[SprengsatzMilitaryFSTime][i] = 0;
		                switch(i)
		                {
		                	case 0:CreateExplosion(MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][2], 7,15);
							case 1:CreateExplosion(MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][2], 7,15);
						}
						WarInfo[MilitaryZerstoert][i] = 1;
						format(string, sizeof(string),"{2ECCFA}INFO: {FFFFFF}Funkstation %i wurde zerstört!",i+1);
						for(new playerid;playerid<MAX_PLAYERS;playerid++)if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)SCM(playerid,-1,string);
						if(IsValidDynamicMapIcon(WarInfo[FunkstationMapIconMilitary][i]))DestroyDynamicMapIcon(WarInfo[FunkstationMapIconMilitary][i]);
					 	if(IsValidObject(WarInfo[SprengsatzObjMilitary][i]))DestroyObject(WarInfo[SprengsatzObjMilitary][i]);
					 	if(WarInfo[MilitaryZerstoert][0] == 1 && WarInfo[MilitaryZerstoert][1] == 1 && WarInfo[WarZoneMilitarySteps] == (sizeof(MilitaryZones)-1))
					 	{
					 	    WarInfo[WarStarted] = 0;
							WarInfo[WarTime] = 0;
							WarInfo[LastWinner] = -1;
							WarInfo[LastRebelsCounter] = WarInfo[RebelsCounter];
							WarInfo[LastMilitaryCounter] = WarInfo[MilitaryCounter];
							WarInfo[LastMatch] = gettime();
							mysql_format(MySQL,query,sizeof(query),"INSERT INTO `novaewarstats` (LastWinner,LastMatch,LastRebelsCounter,LastMilitaryCounter) VALUES ('%i','%i','%i','%i')",WarInfo[LastWinner],WarInfo[LastMatch],WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
							mysql_query(MySQL,query,false);
							eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
							WarInfo[MilitaryCounter] = 0, WarInfo[RebelsCounter] = 0;
							WarInfo[WarZoneRebelSteps] = 0, WarInfo[WarZoneMilitarySteps] = 0;
							for(new p;p<2;p++)WarInfo[BombenLegerIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenLegerIDRebels][p] = INVALID_PLAYER_ID;
							for(new p;p<2;p++)WarInfo[BombenDefuseIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenDefuseIDRebels][p] = INVALID_PLAYER_ID;
							WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID,WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
							for(new p;p<2;p++)WarInfo[RebelsZerstoert][p] = 0, WarInfo[MilitaryZerstoert][p] = 0;
							DestroyNovaeWarVehicles();
					 	}
						if(WarInfo[MilitaryZerstoert][0] == 1 && WarInfo[MilitaryZerstoert][1] == 1)
		                {
		                    GangZoneStopFlashForAll(MilitaryZones[WarInfo[WarZoneMilitarySteps]][WarZoneID]);
		                    GangZoneHideForAll(MilitaryZones[WarInfo[WarZoneMilitarySteps]][WarZoneID]);
		                    WarInfo[WarZoneMilitarySteps]++;
		                    GangZoneFlashForAll(MilitaryZones[WarInfo[WarZoneMilitarySteps]][WarZoneID], 0x80400085);
		                    SetVehicleNovaeWarSpawn(1);
		                    WarInfo[FunkstationMapIconMilitary][0] = CreateDynamicMapIcon(MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][2], 20, 0);
							WarInfo[FunkstationMapIconMilitary][1] = CreateDynamicMapIcon(MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][2], 20, 0);
						}
					}
				}
			}
			if(WarInfo[KillStreakPlayerIDRebels] != INVALID_PLAYER_ID)
			{
			    if(WarInfo[KillStreakRebelsTime] < gettime())
				{
				    if(WarInfo[KillStreakVehRebels] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehRebels]);
				    SetPlayerPos(WarInfo[KillStreakPlayerIDRebels], RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][0],RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][1],RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][2]);
	                SCM(WarInfo[KillStreakPlayerIDRebels],-1,"{2ECCFA}INFO: {FFFFFF}Deine Abschussserie wurde beendet! Du wurdest an den Spawn gesetzt!");
					WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
				}
			}
			if(WarInfo[KillStreakPlayerIDMilitary] != INVALID_PLAYER_ID)
			{
			    if(WarInfo[KillStreakMilitaryTime] < gettime())
				{
				    if(WarInfo[KillStreakVehMilitary] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehMilitary]);
				    SetPlayerPos(WarInfo[KillStreakPlayerIDMilitary], MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][2]);
	                SCM(WarInfo[KillStreakPlayerIDMilitary],-1,"{2ECCFA}INFO: {FFFFFF}Deine Abschussserie wurde beendet! Du wurdest an den Spawn gesetzt!");
					WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID;
				}
			}
		}
	}
	return 1;
}
public OnWarSystemUpdate2()
{
	if(WarInfo[WarStarted] == 1 && WarInfo[WarTime] != 0)
	{
	    new query[128];
	    WarInfo[WarTime]--;
	    if(WarInfo[WarTime] == 121)
	    {
	        for(new i=0;i<MAX_PLAYERS;i++)
	        {
	            if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)
	            {
	                SCM(i,-1,"{2ECCFA}INFO: {FFFFFF}Der Nova-eWar beginnt in einer Minute, begebt euch zu eurem Portpunkt!");
	            }
			}
		}
	    if(WarInfo[WarTime] == 120)
	    {
	        GangZoneFlashForAll(RebelZones[WarInfo[WarZoneRebelSteps]][WarZoneID], 0x056C0096);
	        GangZoneFlashForAll(MilitaryZones[WarInfo[WarZoneMilitarySteps]][WarZoneID], 0x80400085);
	        for(new i=0;i<MAX_PLAYERS;i++)
	        {
	            if(GetPlayerFraktion(i) == 1)
	            {
     				if(IsPlayerInRangeOfPoint(i, 15.0, 268.6505,1883.3195,-30.0938))
     				{
     			    	SetPlayerPos(i,MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][2]);
                    	SCM(i,-1,"{2ECCFA}INFO: {FFFFFF}Du wurdest zum Nova-eWar geportet. Der Kampf hat begonnen, zerstöre die feindlichen Funkstationen.");
				 	}
					ResetPlayerWeapons(i);
					SetPlayerHealth(i, 100.0),SetPlayerArmour(i, 100.0);
					GivePlayerWeapon(i, 24, 300), GivePlayerWeapon(i, 29, 450);
					GivePlayerWeapon(i, 31, 350), GivePlayerWeapon(i, 25, 300);
					SCM(i,-1,"{FFFF00}Nova-eWar Equipment hinzugefügt!");
				}
				if(GetPlayerFraktion(i) == 2)
				{
		            if(IsPlayerInRangeOfPoint(i, 15.0, -1851.8097,-1699.4791,40.8672))
		            {
		                SetPlayerPos(i,RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][0],RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][1],RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][2]);
		                SCM(i,-1,"{2ECCFA}INFO: {FFFFFF}Du wurdest zum Nova-eWar geportet. Der Kampf hat begonnen, zerstöre die feindlichen Funkstationen.");
					}
					ResetPlayerWeapons(i);
					SetPlayerHealth(i, 100.0),SetPlayerArmour(i, 100.0);
					GivePlayerWeapon(i, 24, 300), GivePlayerWeapon(i, 29, 450);
					GivePlayerWeapon(i, 30, 350), GivePlayerWeapon(i, 25, 300);
					SCM(i,-1,"{FFFF00}Nova-eWar Equipment hinzugefügt!");
				}
			}
			CreateNovaeWarVehicles();
			WarInfo[FunkstationMapIconRebels][0] = CreateDynamicMapIcon(RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][2], 20, 0);
			WarInfo[FunkstationMapIconRebels][1] = CreateDynamicMapIcon(RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][2], 20, 0);
			WarInfo[FunkstationMapIconMilitary][0] = CreateDynamicMapIcon(MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][2], 20, 0);
			WarInfo[FunkstationMapIconMilitary][1] = CreateDynamicMapIcon(MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][2], 20, 0);
		}
		if(WarInfo[WarTime] == 60)
		{
		    for(new i=0;i<MAX_PLAYERS;i++)
	        {
	            if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)
	            {
		    		SCM(i,-1,"{2ECCFA}INFO: {FFFFFF}Der Nova-eWar dauert noch 60 Minuten.");
				}
			}
		}
	    if(WarInfo[WarTime] <= 0)
		{
		    new string[128];
		    if(WarInfo[RebelsCounter] == WarInfo[MilitaryCounter])
		    {
		        WarInfo[WarStarted] = 0;
				WarInfo[WarTime] = 0;
				WarInfo[LastWinner] = -1;
				WarInfo[LastRebelsCounter] = WarInfo[RebelsCounter];
				WarInfo[LastMilitaryCounter] = WarInfo[MilitaryCounter];
				WarInfo[LastMatch] = gettime();
				for(new p;p<2;p++)WarInfo[RebelsZerstoert][p] = 0, WarInfo[MilitaryZerstoert][p] = 0;
				mysql_format(MySQL,query,sizeof(query),"INSERT INTO `novaewarstats` (LastWinner,LastMatch,LastRebelsCounter,LastMilitaryCounter) VALUES ('%i','%i','%i','%i')",WarInfo[LastWinner],WarInfo[LastMatch],WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
				mysql_query(MySQL,query,false);
				eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
				WarInfo[MilitaryCounter] = 0, WarInfo[RebelsCounter] = 0;
				WarInfo[WarZoneRebelSteps] = 0, WarInfo[WarZoneMilitarySteps] = 0;
				for(new p;p<2;p++)WarInfo[BombenLegerIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenLegerIDRebels][p] = INVALID_PLAYER_ID;
				for(new p;p<2;p++)WarInfo[BombenDefuseIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenDefuseIDRebels][p] = INVALID_PLAYER_ID;
				WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID,WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
				DestroyNovaeWarVehicles();
				format(string,sizeof(string),"{FF8000}NR Nova-eWar: Der Nova-eWar zwischen den Rebellen und der Bundeswehr ist unentschieden ausgegangen. (R %i - B %i)",
				WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
				SendClientMessageToAll(-1,string);
		        return 1;
			}
			if(WarInfo[RebelsCounter] > WarInfo[MilitaryCounter])
			{
			    WarInfo[WarStarted] = 0;
				WarInfo[WarTime] = 0;
				WarInfo[LastWinner] = 2;
				WarInfo[LastRebelsCounter] = WarInfo[RebelsCounter];
				WarInfo[LastMilitaryCounter] = WarInfo[MilitaryCounter];
				WarInfo[LastMatch] = gettime();
				for(new p;p<2;p++)WarInfo[RebelsZerstoert][p] = 0, WarInfo[MilitaryZerstoert][p] = 0;
				mysql_format(MySQL,query,sizeof(query),"INSERT INTO `novaewarstats` (LastWinner,LastMatch,LastRebelsCounter,LastMilitaryCounter) VALUES ('%i','%i','%i','%i')",WarInfo[LastWinner],WarInfo[LastMatch],WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
				mysql_query(MySQL,query,false);
				eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
				WarInfo[MilitaryCounter] = 0, WarInfo[RebelsCounter] = 0;
				WarInfo[WarZoneRebelSteps] = 0, WarInfo[WarZoneMilitarySteps] = 0;
				for(new p;p<2;p++)WarInfo[BombenLegerIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenLegerIDRebels][p] = INVALID_PLAYER_ID;
				for(new p;p<2;p++)WarInfo[BombenDefuseIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenDefuseIDRebels][p] = INVALID_PLAYER_ID;
				WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID,WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
				DestroyNovaeWarVehicles();
				format(string,sizeof(string),"{FF8000}NR Nova-eWar: Die Rebellen haben den Nova-eWar gegen die Bundeswehr gewonnen. (R %i - B %i)",
				WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
				SendClientMessageToAll(-1,string);
			    return 1;
			}
			if(WarInfo[MilitaryCounter] > WarInfo[RebelsCounter])
			{
			    WarInfo[WarStarted] = 0;
				WarInfo[WarTime] = 0;
				WarInfo[LastWinner] = 1;
				WarInfo[LastRebelsCounter] = WarInfo[RebelsCounter];
				WarInfo[LastMilitaryCounter] = WarInfo[MilitaryCounter];
				WarInfo[LastMatch] = gettime();
				for(new p;p<2;p++)WarInfo[RebelsZerstoert][p] = 0, WarInfo[MilitaryZerstoert][p] = 0;
				mysql_format(MySQL,query,sizeof(query),"INSERT INTO `novaewarstats` (LastWinner,LastMatch,LastRebelsCounter,LastMilitaryCounter) VALUES ('%i','%i','%i','%i')",WarInfo[LastWinner],WarInfo[LastMatch],WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
				mysql_query(MySQL,query,false);
				eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
				WarInfo[MilitaryCounter] = 0, WarInfo[RebelsCounter] = 0;
				WarInfo[WarZoneRebelSteps] = 0, WarInfo[WarZoneMilitarySteps] = 0;
				for(new p;p<2;p++)WarInfo[BombenLegerIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenLegerIDRebels][p] = INVALID_PLAYER_ID;
				for(new p;p<2;p++)WarInfo[BombenDefuseIDMilitary][p] = INVALID_PLAYER_ID,WarInfo[BombenDefuseIDRebels][p] = INVALID_PLAYER_ID;
				WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID,WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
				DestroyNovaeWarVehicles();
				format(string,sizeof(string),"{FF8000}NR Nova-eWar: Die Bundeswehr haben den Nova-eWar gegen die Rebellen gewonnen. (R %i - B %i)",
				WarInfo[LastRebelsCounter],WarInfo[LastMilitaryCounter]);
				SendClientMessageToAll(-1,string);
			    return 1;
			}
		}
	}
	return 1;
}
//COMMAND: /ewarstreak [slot1,slot2,slot3]
COMMAND:ewarstreak(playerid, params[])
{
    if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2) //FraktionsIDs eintragen von Bundeswehr & Rebellen
	{
	    if(WarInfo[WarStarted] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es findet kein Nova-eWar statt!");
	    new cmd[6];
        if(sscanf(params,"s[6]",cmd))return ErrorMSG(playerid,"{A4A4A4}FEHLER: /ewarstreak [slot1/slot2/slot3]");
        if(strcmp(cmd,"slot1",true) == 0)
        {
			if(GetPlayerStreakSlot1(playerid) == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Dein Slot 1 ist leer!");
			GiveKillStreakToPlayer(playerid,GetPlayerStreakSlot1(playerid));
			RemovePlayerStreak1(playerid);
			return 1;
		}
		if(strcmp(cmd,"slot2",true) == 0)
        {
            if(GetPlayerStreakSlot2(playerid) == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Dein Slot 2 ist leer!");
        	GiveKillStreakToPlayer(playerid,GetPlayerStreakSlot2(playerid));
            RemovePlayerStreak2(playerid);
            return 1;
		}
		if(strcmp(cmd,"slot3",true) == 0)
        {
            if(GetPlayerStreakSlot3(playerid) == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Dein Slot 3 ist leer!");
            GiveKillStreakToPlayer(playerid,GetPlayerStreakSlot3(playerid));
            RemovePlayerStreak3(playerid);
            return 1;
		}
		return ErrorMSG(playerid,"{A4A4A4}FEHLER: /ewarstreak [slot1/slot2/slot3]");
	}
	return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du bist kein Mitglied der Bundeswehr oder der Rebellen!");
}
//COMMAND: /ewarhelp
COMMAND:ewarhelp(playerid, params[])
{
    #pragma unused params
    if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2) //FraktionsIDs eintragen von Bundeswehr & Rebellen
	{
	    SCM(playerid,-1,"{DF7401}Nova-eWar Hilfe: {FFFFFF}/ewarstats, /ewar, /ewarstreak");
		if(GetPlayerAdmin(playerid) >= 2)
		{
		    SCM(playerid,-1,"{DF7401}Nova-eWar Hilfe: {FFFFFF}/resetewar, /stopewar, /setnovaewar");
		}
		return 1;
	}
	return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du bist kein Mitglied der Bundeswehr oder der Rebellen!");
}
//COMMAND: /ewarstats
COMMAND:ewarstats(playerid, params[])
{
    #pragma unused params
    if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2) //FraktionsIDs eintragen von Bundeswehr & Rebellen
	{
	    new string[128];
	    format(string, sizeof(string),"WarStreak: %i | WarKills: %i | WarDeaths: %i",GetPlayerWarStreak(playerid),GetPlayerWarKills(playerid),GetPlayerWarDeaths(playerid));
	    SCM(playerid, -1, string);
		format(string, sizeof(string), "Zwischenstand: Bundeswehr: %i Rebellen: %i",WarInfo[MilitaryCounter],WarInfo[RebelsCounter]);
	    return SCM(playerid, -1, string);
	}
	return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du bist kein Mitglied der Bundeswehr oder der Rebellen!");
}
//COMMAND: /stopewar
COMMAND:stopewar(playerid, params[])
{
    #pragma unused params
	new string[128];
    if(GetPlayerAdmin(playerid) >= 2)
	{
	    if(WarInfo[WarStarted] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es findet kein Nova-eWar statt!");
	    format(string,sizeof(string),"{FFFF00}INFO: {FFFFFF}%s hat den Nova-eWar administrativ beendet.",GetName(playerid));
	    for(new i;i<MAX_PLAYERS;i++)if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)SCM(i,-1,string);
	    WarInfo[WarStarted] = 0,WarInfo[WarTime] = 0;
	    WarInfo[RebelsCounter] = 0,WarInfo[MilitaryCounter] = 0;
	    eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID, eWarAnfrage[3] = -1;
	    return SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du hast den Nova-eWar administrativ beendet.");
	}
	return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du bist kein Teammitglied oder dein Rang ist zu niedrig!");
}
//COMMAND: /resetewar
COMMAND:resetewar(playerid, params[])
{
	#pragma unused params
    if(GetPlayerAdmin(playerid) >= 2)
	{
	    new string[128];
	    if(WarInfo[WarStarted] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Nova-eWar muss zu erst gestoppt werden, damit er resettet werden kann!");
	    eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID, eWarAnfrage[3] = -1;
	    format(string,sizeof(string),"{FFFF00}INFO: {FFFFFF}%s hat den Nova-eWar resettet. Er kann nun direkt wieder gestartet werden!",GetName(playerid));
	    for(new i;i<MAX_PLAYERS;i++)if(isPlayerAMember(i,4) && GetPlayerFraktion(i) == 1 || isPlayerAMember(i,4) && GetPlayerFraktion(i) == 2)SCM(i,-1,string);
	    WarInfo[WarStarted] = 0,WarInfo[WarTime] = 0;
	    WarInfo[RebelsCounter] = 0,WarInfo[MilitaryCounter] = 0;
	    WarInfo[LastWinner] = -1,WarInfo[LastMatch] = 0;
	    eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID, eWarAnfrage[3] = -1;
	    return SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Der Nova-eWar wurde resettet. Er kann nun direkt wieder gestartet werden!");
	}
	return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du bist kein Teammitglied oder dein Rang ist zu niedrig!");
}
//COMMAND: /setnovaewar
COMMAND:setnovaewar(playerid, params[])
{
	if(GetPlayerAdmin(playerid) >= 2)
	{
	    if(WarInfo[WarStarted] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Nova-eWar muss zu erst gestoppt werden, damit es deaktiviert werden kann!");
	    new cmd[15],string[128];
    	if(sscanf(params,"s[15]",cmd))return ErrorMSG(playerid,"{A4A4A4}FEHLER: /setnovaewar [aktvieren/deaktivieren]");
    	if(strcmp(cmd,"aktivieren",true) == 0)
    	{
    	    if(WarInfo[ActiveWar] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Das Nova-eWar System wurde bereits aktiviert!");
    	    WarInfo[ActiveWar] = 1;
    	    SCM(playerid, -1, "{2ECCFA}INFO: {FFFFFF}Du hast das Nova-eWar System aktiviert.");
            format(string,sizeof(string),"{2ECCFA}INFO: {FFFFFF}%s hat das Nova-eWar System aktiviert.",GetName(playerid));
			for(new i=0;i<MAX_PLAYERS;i++)if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)SCM(i,-1,string);
		}
		if(strcmp(cmd,"deaktivieren",true) == 0)
		{
		    if(WarInfo[ActiveWar] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Das Nova-eWar System wurde bereits deaktiviert!");
		    WarInfo[ActiveWar] = 0;
		    SCM(playerid, -1, "{2ECCFA}INFO: {FFFFFF}Du hast das Nova-eWar System deaktiviert.");
            format(string,sizeof(string),"{2ECCFA}INFO: {FFFFFF}%s hat das Nova-eWar System deaktiviert.",GetName(playerid));
			for(new i=0;i<MAX_PLAYERS;i++)if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)SCM(i,-1,string);
		}
		return 1;
	}
	return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du bist kein Teammitglied oder dein Rang ist zu niedrig!");
}
//COMMAND: /ewar [anfrage/annehmen/ablehnen]
COMMAND:ewar(playerid, params[])
{
	if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2) //FraktionsIDs eintragen von Bundeswehr & Rebellen
	{
		if(!isPlayerAMember(playerid,4))return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Du kannst erst ab Rang 4 einen Nova-eWar starten.");
		if(WarInfo[ActiveWar] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Das Nova-eWar System wurde von der Administration deaktiviert.");
		if(WarInfo[WarStarted] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es findet bereits ein Nova-eWar statt.");
		new cmd[9],string[128];
		if(sscanf(params,"s[9]",cmd))return ErrorMSG(playerid,"{A4A4A4}FEHLER: /ewar [anfrage/annehmen/ablehnen]");
		if(strcmp(cmd,"anfrage",true) == 0)
		{
	        if(eWarAnfrage[1] > gettime())
	        {
	            return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es wurde bereits eine Anfrage für das Nova-eWar System versendet.");
			}
			else
			{
			    eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID, eWarAnfrage[3] = -1;
			}
			if(eWarAnfrage[0] == 1)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es wurde bereits eine Anfrage für das Nova-eWar System versendet.");
			gettime(stunde,minute,sekunde);
			//if(strcmp(Day(),"Montag",true) == 0 || strcmp(Day(),"Freitag",true))
			{
				//if(stunde<19||stunde>20)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Du kannst einen Nova-eWar nur zwischen 19 und 20 Uhr starten.");
				format(string, sizeof(string),"{FFFF00}INFO: {FFFFFF}Der Antrag für den Nova-eWar wurde von %s versendet.",GetName(playerid));
				if(GetPlayerFraktion(playerid) == 1)
				{
				    eWarAnfrage[0] = 1, eWarAnfrage[1] = (gettime()+60), eWarAnfrage[2] = playerid, eWarAnfrage[3] = GetPlayerFraktion(playerid);
				    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du hast eine Einladung zum Nova-eWar versendet. Die Anfrage verfällt automatisch nach 60 Sekunden.");
				    for(new i;i<MAX_PLAYERS;i++)
					{
						if(isPlayerAMember(i,4) && GetPlayerFraktion(i) == 2)
						{
							SCM(i,-1,"{FFFF00}INFO: {FFFFFF}Die Bundeswehr möchte einen Nova-eWar starten. Tippe {DF7401}/ewar annehmen {FFFFFF} um die Herausforderung anzunehmen.");
							SCM(i,-1,"{FFFF00}INFO: {FFFFFF}Um die Herausforderung abzulehnen, tippe {DF7401}/ewar ablehnen{FFFFFF}.");
							SCM(i,-1,string);
							SCM(i,-1,"{A4A4A4}Tipp: Vor jedem Nova-eWar gibt es eine 5-minütige Vorbereitungszeit.");
						}
					}
				}
				else if(GetPlayerFraktion(playerid) == 2)
				{
				    eWarAnfrage[0] = 1, eWarAnfrage[1] = (gettime()+60), eWarAnfrage[2] = playerid, eWarAnfrage[3] = GetPlayerFraktion(playerid);
				    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du hast eine Einladung zum Nova-eWar versendet. Die Anfrage verfällt automatisch nach 60 Sekunden.");
				    for(new i;i<MAX_PLAYERS;i++)
					{
						if(isPlayerAMember(i,4) && GetPlayerFraktion(i) == 1)
						{
							SCM(i,-1,"{FFFF00}INFO: {FFFFFF}Die Rebellen möchten einen Nova-eWar starten. Tippe {DF7401}/ewar annehmen {FFFFFF} um die Herausforderung anzunehmen.");
							SCM(i,-1,"{FFFF00}INFO: {FFFFFF}Um die Herausforderung abzulehnen, tippe {DF7401}/ewar ablehnen{FFFFFF}.");
							SCM(i,-1,string);
				   		 	SCM(i,-1,"{A4A4A4}Tipp: Vor jedem Nova-eWar gibt es eine 5-minütige Vorbereitungszeit.");
						}
					}
				}
				return 1;
			}
			//return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Du kannst einen Nova-eWar nur Montags und Freitags starten!");
		}
		if(strcmp(cmd,"annehmen",true) == 0)
		{
		    if(eWarAnfrage[0] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es wurde keine Nova-eWar Anfrage gesendet.");
			if(eWarAnfrage[2] == playerid)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du kannst nicht deine eigene Nova-eWar Anfrage annehmen.");
			if(eWarAnfrage[1] < gettime())
			{
			    eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
				return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es wurde keine Nova-eWar Anfrage gesendet.");
			}
			if(eWarAnfrage[3] == GetPlayerFraktion(playerid))return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Die Nova-eWar Anfrage kann nur von der anderen Fraktion angenommen werden.");
			for(new i;i<MAX_PLAYERS;i++)if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)SCM(i, -1,"{FFFF00}INFO: {FFFFFF}Das Nova-eWar wurde gestartet. Es beginnt nun die 5-minütige Vorbereitungszeit.");
			WarInfo[WarStarted] = 1;
			WarInfo[WarTime] = 125;
			eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
			WarInfo[WarZoneRebelSteps] = 0, WarInfo[WarZoneMilitarySteps] = 0;
			WarInfo[WarRebelsBlockPlant] = (gettime() + (5*60));
			WarInfo[WarMilitaryBlockPlant] = (gettime()  + (5*60));
			return 1;
		}
		if(strcmp(cmd,"ablehnen",true) == 0)
		{
			if(eWarAnfrage[0] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es wurde keine Nova-eWar Anfrage gesendet.");
			if(eWarAnfrage[2] == playerid)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du kannst nicht deine eigene Nova-eWar Anfrage ablehnen.");
			if(eWarAnfrage[1] < gettime())
			{
			    eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
				return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Es wurde keine Nova-eWar Anfrage gesendet.");
			}
			if(eWarAnfrage[3] == GetPlayerFraktion(playerid))return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Die Nova-eWar Anfrage kann nur von der anderen Fraktion angenommen werden.");
			format(string, sizeof(string),"{FFFF00}INFO: {FFFFFF}Die Nova-eWar Anfrage von %s wurde von %s abgelehnt.",GetName(eWarAnfrage[2]),GetName(playerid));
			for(new i;i<MAX_PLAYERS;i++)if(GetPlayerFraktion(i) == eWarAnfrage[3])SCM(i, -1,string);
			eWarAnfrage[0] = 0, eWarAnfrage[1] = 0, eWarAnfrage[2] = INVALID_PLAYER_ID,eWarAnfrage[3] = -1;
			return 1;
		}
		return ErrorMSG(playerid,"{A4A4A4}FEHLER: /ewar [anfrage/annehmen/ablehnen]");
	}
	return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Du bist kein Mitglied der Bundeswehr oder der Rebellen!");
}

main()
{
	print("\n----------------------------------");
	print("Rebellen vs Bundeswehr");
	print("----------------------------------\n");
}


public OnGameModeInit()
{
	SetGameModeText("Nova-eWars");
	AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
	getdate(jahr,monat,tag);
	InitializeWarSystem();
	CreateObject(3250,-100.110,2797.847,76.885,0.799,0.000,85.599,300.000);//Haus Huhngebiet
	mysql_log(LOG_ERROR | LOG_WARNING, LOG_TYPE_HTML);
	MySQL = mysql_connect("localhost", "root", "novawardb", "1234");
	return 1;
}

public OnGameModeExit()
{
    UpdateNovaWar();
    mysql_close(MySQL);
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	SetPlayerPos(playerid, 1958.3783, 1343.1572, 15.3746);
	SetPlayerCameraPos(playerid, 1958.3783, 1343.1572, 15.3746);
	SetPlayerCameraLookAt(playerid, 1958.3783, 1343.1572, 15.3746);
	return 1;
}

public OnPlayerConnect(playerid)
{
	GetPlayerName(playerid, PlayerName[playerid],MAX_PLAYER_NAME);
	DestroyVars(playerid);
	PreloadAnimLib(playerid, "BOMBER");
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    DestroyVars(playerid);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	/*NUR ZU TESTZWECKEN*/
    if(strcmp(GetName(playerid),"Dominik",true) == 0)SetPVarInt(playerid, "Fraktion", 1), SetPVarInt(playerid, "Rang", 4), SetPVarInt(playerid, "Admin", 2);
    if(strcmp(GetName(playerid),"Hampelmann",true) == 0)SetPVarInt(playerid, "Fraktion", 1), SetPVarInt(playerid, "Rang", 4), SetPVarInt(playerid, "Admin", 2);
    if(strcmp(GetName(playerid),"Shaggy",true) == 0)SetPVarInt(playerid, "Fraktion", 2), SetPVarInt(playerid, "Rang", 4), SetPVarInt(playerid, "Admin", 2);
    if(strcmp(GetName(playerid),"AToD",true) == 0)SetPVarInt(playerid, "Fraktion", 2), SetPVarInt(playerid, "Rang", 4), SetPVarInt(playerid, "Admin", 2);
    SetPVarInt(playerid, "Admin", 2);
    if(GetPlayerFraktion(playerid) == 1)SetPlayerSkin(playerid, 287);
    if(GetPlayerFraktion(playerid) == 2)SetPlayerSkin(playerid, 220);
    /*NUR ZU TESTZWECKEN*/
    if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)
	{
		ShowPlayerKriegszone(playerid);
	    if(WarInfo[WarStarted] == 1 && WarInfo[WarTime] != 0  && WarInfo[WarTime] <= 120)
		{
		    if(GetPlayerFraktion(playerid) == 1)
			{
				SetPlayerPos(playerid, MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][HQSpawn][2]);
            	ResetPlayerWeapons(playerid);
				SetPlayerHealth(playerid, 100.0),SetPlayerArmour(playerid, 100.0);
				GivePlayerWeapon(playerid, 24, 300), GivePlayerWeapon(playerid, 29, 450);
				GivePlayerWeapon(playerid, 31, 350), GivePlayerWeapon(playerid, 25, 300);
				SCM(playerid,-1,"{FFFF00}Nova-eWar Equipment hinzugefügt!");
			}
		    else if(GetPlayerFraktion(playerid) == 2)
			{
				SetPlayerPos(playerid, RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][0],RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][1],RebelZones[WarInfo[WarZoneRebelSteps]][HQSpawn][2]);
                ResetPlayerWeapons(playerid);
				SetPlayerHealth(playerid, 100.0),SetPlayerArmour(playerid, 100.0);
				GivePlayerWeapon(playerid, 24, 300), GivePlayerWeapon(playerid, 29, 450);
				GivePlayerWeapon(playerid, 30, 350), GivePlayerWeapon(playerid, 25, 300);
				SCM(playerid,-1,"{FFFF00}Nova-eWar Equipment hinzugefügt!");
			}
		}
		ClearAnimations(playerid);
	}
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	new string[128];
	if(IsPlayerNPC(playerid))return 1;
	if(WarInfo[WarStarted] == 1 && WarInfo[WarTime] != 0 && WarInfo[WarTime] <= 120)
	{
		if(GetPlayerFraktion(playerid) == 1 && GetPlayerFraktion(killerid) == 2 ||
		GetPlayerFraktion(playerid) == 2 && GetPlayerFraktion(killerid) == 1)
		{
			if(killerid != INVALID_PLAYER_ID)
			{
				AddPlayerWarKill(killerid);
				AddPlayerStreakKill(killerid);
				CheckStreak(killerid);
				if(GetPlayerFraktion(killerid) == 1)WarInfo[MilitaryCounter]++;
				if(GetPlayerFraktion(killerid) == 2)WarInfo[RebelsCounter]++;
			}
			ClearAnimations(playerid);
			SendWarDeathMessage(playerid, killerid, reason);
   			AddPlayerWarDeath(playerid),RemovePlayerWarStreak(playerid);
		}
		else if(GetPlayerFraktion(playerid) == 2 && GetPlayerFraktion(killerid) == 2 ||
		GetPlayerFraktion(playerid) == 1 && GetPlayerFraktion(killerid) == 1)
		{
		    GameTextForPlayer(playerid, "~r~Teamkill", 2500, 6);
		    GameTextForPlayer(killerid, "~r~Teamkill", 2500, 6);
		    ClearAnimations(playerid);
			SendWarDeathMessage(playerid, killerid, reason);
   			AddPlayerWarDeath(playerid),RemovePlayerWarStreak(playerid);
		}
		for(new i = 0; i < 2; i++)
		{
	    	if(WarInfo[BombenDefuseIDMilitary][i] == playerid)
	    	{
	    	    WarInfo[BombenDefuseIDMilitary][i] = INVALID_PLAYER_ID;
    			WarInfo[BombenDefuseMilitary][i] = 0;
    			format(string,sizeof(string),"{FFFF00}INFO: {FFFFFF}%s wurde beim entschärfen eines Sprengsatzes getötet.",GetName(playerid));
                for(new p = 0;p<MAX_PLAYERS;p++)if(GetPlayerFraktion(p) == 1 || GetPlayerFraktion(p) == 2)SCM(p, -1,string);
			}
			else if(WarInfo[BombenDefuseIDRebels][i] == playerid)
	    	{
	    	    WarInfo[BombenDefuseIDRebels][i] = INVALID_PLAYER_ID;
    			WarInfo[BombenDefuseRebels][i] = 0;
    			format(string,sizeof(string),"{FFFF00}INFO: {FFFFFF}%s wurde beim entschärfen eines Sprengsatzes getötet.",GetName(playerid));
                for(new p = 0;p<MAX_PLAYERS;p++)if(GetPlayerFraktion(p) == 1 || GetPlayerFraktion(p) == 2)SCM(p, -1,string);
			}
			else if(WarInfo[BombenLegerIDMilitary][i] == playerid)
	    	{
	    	    WarInfo[BombenLegerIDMilitary][i] = INVALID_PLAYER_ID;
    			WarInfo[BombenLegerMilitary][i] = 0;
    			format(string,sizeof(string),"{FFFF00}INFO: {FFFFFF}%s wurde beim Versuch ein Sprengsatz zu platzieren getötet.",GetName(playerid));
                for(new p = 0;p<MAX_PLAYERS;p++)if(GetPlayerFraktion(p) == 1 || GetPlayerFraktion(p) == 2)SCM(p, -1,string);
			}
			else if(WarInfo[BombenLegerIDRebels][i] == playerid)
	    	{
	    	    WarInfo[BombenLegerIDRebels][i] = INVALID_PLAYER_ID;
    			WarInfo[BombenLegerRebels][i] = 0;
    			format(string,sizeof(string),"{FFFF00}INFO: {FFFFFF}%s wurde beim Versuch ein Sprengsatz zu platzieren getötet.",GetName(playerid));
                for(new p = 0;p<MAX_PLAYERS;p++)if(GetPlayerFraktion(p) == 1 || GetPlayerFraktion(p) == 2)SCM(p, -1,string);
			}
		}
	}
	if(WarInfo[KillStreakPlayerIDMilitary] == playerid)
	{
	    SCM(playerid,-1,"{2ECCFA}INFO: {FFFFFF}Deine Abschussserie wurde beendet, da du gestorben bist.");
	    DestroyVehicle(WarInfo[KillStreakVehMilitary]);
		WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID;
		WarInfo[KillStreakMilitaryTime] = 0;
	}
	if(WarInfo[KillStreakPlayerIDRebels] == playerid)
	{
	    SCM(playerid,-1,"{2ECCFA}INFO: {FFFFFF}Deine Abschussserie wurde beendet, da du gestorben bist.");
	    DestroyVehicle(WarInfo[KillStreakVehRebels]);
		WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
		WarInfo[KillStreakRebelsTime] = 0;
	}
	return 1;
}

stock GiveKillStreakToPlayer(playerid, StreakID)
{
	new string[144];
    format(string, sizeof(string),"{2ECCFA}Nova-eWar Info: {FFFFFF}%s hat seine Errungenschaft bei seiner Kill Streak eingelöst (%s).",GetName(playerid),GetKillStreakByID(StreakID));
    for(new i=0;i<MAX_PLAYERS;i++)if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)SCM(i,-1,string);
	switch(StreakID)
    {
        case 1:
        {
            GivePlayerWeapon(playerid, 33, 30);
            SCM(playerid, -1, "{FFFF00}INFO: {FFFFFF}Du wurdest erfolgreich mit der Country Rifle ausgestattet (30 Munition).");
            return 1;
		}
        case 2:
        {
            GivePlayerWeapon(playerid, 16, 5);
            SCM(playerid, -1, "{FFFF00}INFO: {FFFFFF}Du wurdest erfolgreich mit Handgranaten ausgestattet (5 Stück).");
            return 1;
		}
        case 3:
        {
            GivePlayerWeapon(playerid, 34, 30);
            SCM(playerid, -1, "{FFFF00}INFO: {FFFFFF}Du wurdest erfolgreich mit der Sniper Rifle ausgestattet (30 Munition).");
            return 1;
		}
        case 4:
        {
            switch(GetPlayerFraktion(playerid))
            {
				case 1:
				{
				    if(WarInfo[KillStreakPlayerIDMilitary] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDMilitary] = playerid;
				    WarInfo[KillStreakMilitaryTime] = (gettime() + 30);
					if(WarInfo[KillStreakVehMilitary] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehMilitary]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehMilitary] = CreateVehicle(447,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehMilitary], 0);
					SetVehicleSpeed(WarInfo[KillStreakVehMilitary], 10.0);
					return 1;
				}
				case 2:
				{
				    if(WarInfo[KillStreakPlayerIDRebels] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDRebels] = playerid;
				    WarInfo[KillStreakRebelsTime] = (gettime() + 30);
					if(WarInfo[KillStreakVehRebels] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehRebels]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehRebels] = CreateVehicle(447,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehRebels], 0);
				    SetVehicleSpeed(WarInfo[KillStreakVehRebels], 10.0);
				    return 1;
				}
			}
		}
        case 5:
        {
            GivePlayerWeapon(playerid, 35, 3);
            SCM(playerid, -1, "{FFFF00}INFO: {FFFFFF}Du wurdest erfolgreich mit der RPG ausgestattet (3 Schuss).");
            return 1;
		}
        case 6:
        {
            switch(GetPlayerFraktion(playerid))
            {
				case 1:
				{
				    if(WarInfo[KillStreakPlayerIDMilitary] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDMilitary] = playerid;
				    WarInfo[KillStreakMilitaryTime] = (gettime() + 60);
					if(WarInfo[KillStreakVehMilitary] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehMilitary]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehMilitary] = CreateVehicle(447,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehMilitary], 0);
					SetVehicleSpeed(WarInfo[KillStreakVehMilitary], 10.0);
					return 1;
				}
				case 2:
				{
				    if(WarInfo[KillStreakPlayerIDRebels] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDRebels] = playerid;
				    WarInfo[KillStreakRebelsTime] = (gettime() + 60);
					if(WarInfo[KillStreakVehRebels] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehRebels]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehRebels] = CreateVehicle(447,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehRebels], 0);
					SetVehicleSpeed(WarInfo[KillStreakVehRebels], 10.0);
					return 1;
				}
			}
		}
        case 7:
        {
            switch(GetPlayerFraktion(playerid))
            {
				case 1:
				{
				    if(WarInfo[KillStreakPlayerIDMilitary] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDMilitary] = playerid;
				    WarInfo[KillStreakMilitaryTime] = (gettime() + 30);
					if(WarInfo[KillStreakVehMilitary] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehMilitary]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehMilitary] = CreateVehicle(425,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehMilitary], 0);
					SetVehicleSpeed(WarInfo[KillStreakVehMilitary], 10.0);
					return 1;
				}
				case 2:
				{
				    if(WarInfo[KillStreakPlayerIDRebels] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDRebels] = playerid;
				    WarInfo[KillStreakRebelsTime] = (gettime() + 30);
					if(WarInfo[KillStreakVehRebels] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehRebels]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehRebels] = CreateVehicle(425,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehRebels], 0);
					SetVehicleSpeed(WarInfo[KillStreakVehRebels], 10.0);
					return 1;
				}
			}
		}
        case 8:
        {
            GivePlayerWeapon(playerid, 36, 3);
            SCM(playerid, -1, "{FFFF00}INFO: {FFFFFF}Du wurdest erfolgreich mit der HS Rocket ausgestattet (3 Schuss).");
            return 1;
		}
        case 9:
        {
            switch(GetPlayerFraktion(playerid))
            {
				case 1:
				{
				    if(WarInfo[KillStreakPlayerIDMilitary] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDMilitary] = playerid;
				    WarInfo[KillStreakMilitaryTime] = (gettime() + 60);
					if(WarInfo[KillStreakVehMilitary] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehMilitary]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehMilitary] = CreateVehicle(425,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehMilitary], 0);
					SetVehicleSpeed(WarInfo[KillStreakVehMilitary], 10.0);
					return 1;
				}
				case 2:
				{
				    if(WarInfo[KillStreakPlayerIDRebels] != INVALID_PLAYER_ID)return ErrorMSG(playerid, "{DF0101}FEHLER: {FFFFFF}Es befindet sich bereits ein Fahrzeug aus eurem Team im Kampf!");
				    WarInfo[KillStreakPlayerIDRebels] = playerid;
				    WarInfo[KillStreakRebelsTime] = (gettime() + 60);
					if(WarInfo[KillStreakVehRebels] != INVALID_VEHICLE_ID) DestroyVehicle(WarInfo[KillStreakVehRebels]);
					GetPlayerPos(playerid, PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]),GetPlayerFacingAngle(playerid, PlayerWarPos[playerid][3]);
					WarInfo[KillStreakVehRebels] = CreateVehicle(425,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1],PlayerWarPos[playerid][2]+25.0,PlayerWarPos[playerid][3],16,16,-1);
                    PutPlayerInVehicle(playerid, WarInfo[KillStreakVehRebels], 0);
					SetVehicleSpeed(WarInfo[KillStreakVehRebels], 10.0);
					return 1;
				}
			}
		}
        case 10:
        {
            GivePlayerWeapon(playerid, 38, 50);
            SCM(playerid, -1, "{FFFF00}INFO: {FFFFFF}Du wurdest erfolgreich mit einer Minigun ausgestattet (50 Munition).");
			return 1;
		}
		default:{return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Dieser Slot ist leer!");}
	}
	return 1;
}

stock CheckStreak(playerid)
{
	new streakid = 0;
	switch(GetPlayerWarStreak(playerid))
	{
	    case 3:
	    {
	        GameTextForPlayer(playerid, "Killing Spree", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}3er Abschussserie: 30 Schuss Country Rifle");
	        streakid = 1;
		}
	    case 5:
	    {
	        GameTextForPlayer(playerid, "Mega Kill", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}5er Abschussserie: 5 Handgranaten");
	        streakid = 2;
		}
	    case 7:
	    {
	        GameTextForPlayer(playerid, "Monster Kill", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}7er Abschussserie: 30 Schuss Sniper Rifle");
	        streakid = 3;
		}
	    case 9:
	    {
	        GameTextForPlayer(playerid, "Rampage", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}9er Abschussserie: 30 Sekunden Seasparrow");
	        streakid = 4;
		}
	    case 11:
	    {
	        GameTextForPlayer(playerid, "Unstoppable", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}11er Abschussserie: 3 Schuss RPG");
	        streakid = 5;
		}
		case 13:
		{
	        GameTextForPlayer(playerid, "Wicked Sick", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}13er Abschussserie: 60 Sekunden Seasparrow");
	        streakid = 6;
		}
		case 15:
		{
	        GameTextForPlayer(playerid, "Dominating", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}15er Abschussserie: 30 Sekunden Hunter");
	        streakid = 7;
		}
		case 17:
		{
	        GameTextForPlayer(playerid, "Untouchable", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}17er Abschussserie: 3 Schuss HS Rocket");
	        streakid = 8;
		}
		case 19:
		{
	        GameTextForPlayer(playerid, "Godlike", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}19er Abschussserie: 60 Sekunden Hunter");
	        streakid = 9;
		}
		case 21:
		{
	        GameTextForPlayer(playerid, "Legendary", 5000, 6);
	        SCM(playerid,-1,"{F7FE2E}21er Abschussserie: 50 Schuss Minigun");
	        streakid = 10;
	        RemovePlayerWarStreak(playerid);
		}
	}
	if(GetPlayerStreakSlot1(playerid) == 0) return SetPlayerStreakSlot1(playerid,streakid);
	if(GetPlayerStreakSlot2(playerid) == 0) return SetPlayerStreakSlot2(playerid,streakid);
	if(GetPlayerStreakSlot3(playerid) == 0) return SetPlayerStreakSlot3(playerid,streakid);
	if(GetPlayerStreakSlot1(playerid) == 1 && GetPlayerStreakSlot2(playerid) == 1 && GetPlayerStreakSlot3(playerid) == 1)return ErrorMSG(playerid,"{FFFF00}INFO: {FFFFFF}Es ist kein Killstreak Slot mehr frei! Nutze erst deine Killstreaks mit {DF7401}/ewarstreak{FFFFFF}.");
	return 1;
}

stock SendWarDeathMessage(playerid, killerid, reason)
{
	for(new i=0;i<MAX_PLAYERS;i++)
	{
		if(GetPlayerFraktion(i) == 1 || GetPlayerFraktion(i) == 2)SendDeathMessageToPlayer(i, killerid, playerid, reason);
	}
	return 1;
}

stock RemoveDeathmessages(playerid)
{
    for(new i = 0; i<5; i++) SendDeathMessageToPlayer(playerid, 9999, 9998, 255);
    return 1;
}

stock SetVehicleSpeed(vehicleid, Float:speed)
{
    new Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, Float:a;
    GetVehicleVelocity(vehicleid, x1, y1, z1);
    GetVehiclePos(vehicleid, x2, y2, z2);
    GetVehicleZAngle(vehicleid, a); a = 360 - a;
    x1 = (floatsin(a, degrees) * (speed/100) + floatcos(a, degrees) * 0 + x2) - x2;
    y1 = (floatcos(a, degrees) * (speed/100) + floatsin(a, degrees) * 0 + y2) - y2;
    SetVehicleVelocity(vehicleid, x1, y1, z1);
}

stock OnePlayAnim(playerid,animlib[],animname[], Float:Speed, looping, lockx, locky, lockz, lp)
{
	ApplyAnimation(playerid, animlib, animname, Speed, looping, lockx, locky, lockz, lp);
}

stock PreloadAnimLib(playerid, animlib[])
{
	ApplyAnimation(playerid,animlib,"null",0.0,0,0,0,0,0);
}

public OnVehicleSpawn(vehicleid)
{
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	return 1;
}

public OnPlayerText(playerid, text[])
{
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	if(WarInfo[KillStreakVehMilitary] == vehicleid && WarInfo[KillStreakPlayerIDMilitary] != playerid && WarInfo[KillStreakPlayerIDMilitary] != INVALID_PLAYER_ID)
	{
	    DestroyVehicle(WarInfo[KillStreakVehMilitary]);
		WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID;
		WarInfo[KillStreakMilitaryTime] = 0;
		return 1;
	}
	if(WarInfo[KillStreakVehRebels] == vehicleid && WarInfo[KillStreakPlayerIDRebels] != playerid && WarInfo[KillStreakPlayerIDRebels] != INVALID_PLAYER_ID)
    {
		DestroyVehicle(WarInfo[KillStreakVehRebels]);
		WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
		WarInfo[KillStreakRebelsTime] = 0;
		return 1;
	}
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    if(WarInfo[KillStreakVehMilitary] == vehicleid && WarInfo[KillStreakPlayerIDMilitary] == playerid)
    {
		DestroyVehicle(WarInfo[KillStreakVehMilitary]);
  		SCM(playerid,-1,"{2ECCFA}INFO: {FFFFFF}Deine Abschussserie wurde beendet, da du ausgestiegen bist.");
		WarInfo[KillStreakPlayerIDMilitary] = INVALID_PLAYER_ID;
		WarInfo[KillStreakMilitaryTime] = 0;
		return 1;
	}
	if(WarInfo[KillStreakVehRebels] == vehicleid && WarInfo[KillStreakPlayerIDRebels] == playerid)
    {
		DestroyVehicle(WarInfo[KillStreakVehRebels]);
  		SCM(playerid,-1,"{2ECCFA}INFO: {FFFFFF}Deine Abschussserie wurde beendet, da du ausgestiegen bist.");
		WarInfo[KillStreakPlayerIDRebels] = INVALID_PLAYER_ID;
		WarInfo[KillStreakRebelsTime] = 0;
		return 1;
	}
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	return 1;
}

public OnRconCommand(cmd[])
{
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	return 1;
}

public OnObjectMoved(objectid)
{
	return 1;
}

public OnPlayerObjectMoved(playerid, objectid)
{
	return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
	return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid)
{
	return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	return 1;
}

public OnPlayerSelectedMenuRow(playerid, row)
{
	return 1;
}

public OnPlayerExitedMenu(playerid)
{
	return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	new string[128],time;
    if(newkeys & KEY_NO)
    {
        if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)
        {
        	if(WarInfo[WarStarted] == 1 && WarInfo[WarTime] != 0)
        	{
				if(IsPlayerInRangeOfPoint(playerid, 3.0, RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation1][2]) && GetPlayerFraktion(playerid) == 1)
				{
				    if(WarInfo[BombenLegerIDRebels][0] == playerid)
				    {
				        SCM(playerid,-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast den Vorgang selbstständig abgebrochen.");
				        WarInfo[BombenLegerIDRebels][0] = INVALID_PLAYER_ID;
				    	WarInfo[BombenLegerRebels][0] = 0;
				        return ClearAnimations(playerid);
					}
				    if(WarInfo[BombenLegerIDRebels][0] != INVALID_PLAYER_ID)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz wird bereits von einer anderen Person platziert!");
					if(WarInfo[SprengsatzRebelsFS][0] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz ist bereits platziert.");
					time = WarInfo[WarRebelsBlockPlant] - gettime();
				    format(string,sizeof(string),"{DF0101}FEHLER: {FFFFFF}Der nächste Sprengsatz kann erst in %i Sekunden platziert werden!",time);
				    if(WarInfo[WarRebelsBlockPlant] > gettime())return ErrorMSG(playerid,string);
				    GetPlayerPos(playerid,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1], PlayerWarPos[playerid][2]);
				    ClearAnimations(playerid),OnePlayAnim(playerid, "BOMBER", "BOM_Plant", 4.0, 1,1,1,1, 0);
				    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du beginnst den Sprengsatz zu platzieren! (Dauer: 60 Sekunden)");
				    WarInfo[BombenLegerIDRebels][0] = playerid;
				    WarInfo[BombenLegerRebels][0] = gettime()+60;
				    return 1;
				}
				else if(IsPlayerInRangeOfPoint(playerid, 3.0, RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][0],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][1],RebelZones[WarInfo[WarZoneRebelSteps]][FunkStation2][2]) && GetPlayerFraktion(playerid) == 1)
				{
				    if(WarInfo[BombenLegerIDRebels][1] == playerid)
				    {
				        SCM(playerid,-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast den Vorgang selbstständig abgebrochen.");
				        WarInfo[BombenLegerIDRebels][1] = INVALID_PLAYER_ID;
				    	WarInfo[BombenLegerRebels][1] = 0;
				        return ClearAnimations(playerid);
					}
				    if(WarInfo[BombenLegerIDRebels][1] != INVALID_PLAYER_ID)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz wird bereits von einer anderen Person platziert!");
                    if(WarInfo[SprengsatzRebelsFS][1] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz ist bereits platziert.");
					time = WarInfo[WarRebelsBlockPlant] - gettime();
				    format(string,sizeof(string),"{DF0101}FEHLER: {FFFFFF}Der nächste Sprengsatz kann erst in %i Sekunden platziert werden!",time);
				    if(WarInfo[WarRebelsBlockPlant] > gettime())return ErrorMSG(playerid,string);
				    GetPlayerPos(playerid,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1], PlayerWarPos[playerid][2]);
				    ClearAnimations(playerid),OnePlayAnim(playerid, "BOMBER", "BOM_Plant", 4.0, 1,1,1,1, 0);
				    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du beginnst den Sprengsatz zu platzieren! (Dauer: 60 Sekunden)");
				    WarInfo[BombenLegerIDRebels][1] = playerid;
				    WarInfo[BombenLegerRebels][1] = gettime()+60;
				    return 1;
				}
				else if(IsPlayerInRangeOfPoint(playerid, 3.0, MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation1][2]) && GetPlayerFraktion(playerid) == 2)
				{
				    if(WarInfo[BombenLegerIDMilitary][0] == playerid)
				    {
				        SCM(playerid,-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast den Vorgang selbstständig abgebrochen.");
				        WarInfo[BombenLegerIDMilitary][0] = INVALID_PLAYER_ID;
				    	WarInfo[BombenLegerMilitary][0] = 0;
				        return ClearAnimations(playerid);
					}
				    if(WarInfo[BombenLegerIDMilitary][0] != INVALID_PLAYER_ID)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz wird bereits von einer anderen Person platziert!");
                    if(WarInfo[SprengsatzMilitaryFS][0] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz ist bereits platziert.");
					time = WarInfo[WarMilitaryBlockPlant] - gettime();
				    format(string,sizeof(string),"{DF0101}FEHLER: {FFFFFF}Der nächste Sprengsatz kann erst in %i Sekunden platziert werden!",time);
				    if(WarInfo[WarMilitaryBlockPlant] > gettime())return ErrorMSG(playerid,string);
				    GetPlayerPos(playerid,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1], PlayerWarPos[playerid][2]);
				    ClearAnimations(playerid),OnePlayAnim(playerid, "BOMBER", "BOM_Plant", 4.0, 1,1,1,1, 0);
				    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du beginnst den Sprengsatz zu platzieren! (Dauer: 60 Sekunden)");
				    WarInfo[BombenLegerIDMilitary][0] = playerid;
				    WarInfo[BombenLegerMilitary][0] = gettime()+60;
				    return 1;
				}
				else if(IsPlayerInRangeOfPoint(playerid, 3.0, MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][0],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][1],MilitaryZones[WarInfo[WarZoneMilitarySteps]][FunkStation2][2]) && GetPlayerFraktion(playerid) == 2)
				{
				    if(WarInfo[BombenLegerIDMilitary][1] == playerid)
				    {
				        SCM(playerid,-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast den Vorgang selbstständig abgebrochen.");
				        WarInfo[BombenLegerIDMilitary][1] = INVALID_PLAYER_ID;
				    	WarInfo[BombenLegerMilitary][1] = 0;
				        return ClearAnimations(playerid);
					}
				    if(WarInfo[BombenLegerIDMilitary][1] != INVALID_PLAYER_ID)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz wird bereits von einer anderen Person platziert!");
                    if(WarInfo[SprengsatzMilitaryFS][1] == 1)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz ist bereits platziert.");
					time = WarInfo[WarMilitaryBlockPlant] - gettime();
				    format(string,sizeof(string),"{DF0101}FEHLER: {FFFFFF}Der nächste Sprengsatz kann erst in %i Sekunden platziert werden!",time);
				    if(WarInfo[WarMilitaryBlockPlant] > gettime())return ErrorMSG(playerid,string);
				    GetPlayerPos(playerid,PlayerWarPos[playerid][0], PlayerWarPos[playerid][1], PlayerWarPos[playerid][2]);
				    ClearAnimations(playerid),OnePlayAnim(playerid, "BOMBER", "BOM_Plant", 4.0, 1,1,1,1, 0);
				    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du beginnst den Sprengsatz zu platzieren! (Dauer: 60 Sekunden)");
				    WarInfo[BombenLegerIDMilitary][1] = playerid;
				    WarInfo[BombenLegerMilitary][1] = gettime()+60;
				    return 1;
				}
				return 1;
			}
		}
	}
	if(newkeys & KEY_YES)
	{
	    if(GetPlayerFraktion(playerid) == 1 || GetPlayerFraktion(playerid) == 2)
        {
        	if(WarInfo[WarStarted] == 1 && WarInfo[WarTime] != 0)
        	{
        	    new Float:ObjPos[3];
        	    for(new i=0;i<2;i++)
				{
				    GetObjectPos(WarInfo[SprengsatzObjRebel][i],ObjPos[0], ObjPos[1], ObjPos[2]);
				    if(IsPlayerInRangeOfPoint(playerid, 2.0, ObjPos[0], ObjPos[1], ObjPos[2]) && GetPlayerFraktion(playerid) == 2)
					{
					    if(WarInfo[BombenDefuseIDRebels][i] == playerid)
					    {
					        SCM(playerid,-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast den Vorgang selbstständig abgebrochen.");
					        WarInfo[BombenDefuseIDRebels][i] = INVALID_PLAYER_ID;
					    	WarInfo[BombenDefuseRebels][i] = 0;
					        return ClearAnimations(playerid);
						}
					    if(WarInfo[SprengsatzRebelsFS][i] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz ist nicht platziert.");
					    if(WarInfo[BombenDefuseIDRebels][i] != INVALID_PLAYER_ID)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Eine Person entschärft bereits den Sprengsatz!");
					    ClearAnimations(playerid),OnePlayAnim(playerid, "BOMBER", "BOM_Plant", 4.0, 1,1,1,1, 0);
					    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du beginnst den Sprengsatz zu entschärfen! (Dauer: 40 Sekunden)");
					    WarInfo[BombenDefuseIDRebels][i] = playerid;
					    WarInfo[BombenDefuseRebels][i] = (gettime()+40);
					    return 1;
					}
					GetObjectPos(WarInfo[SprengsatzObjMilitary][i],ObjPos[0], ObjPos[1], ObjPos[2]);
					if(IsPlayerInRangeOfPoint(playerid, 2.0, ObjPos[0], ObjPos[1], ObjPos[2]) && GetPlayerFraktion(playerid) == 1)
					{
					    if(WarInfo[BombenDefuseIDMilitary][i] == playerid)
					    {
					        SCM(playerid,-1,"{DF0101}Abgebrochen: {FFFFFF}Du hast den Vorgang selbstständig abgebrochen.");
					        WarInfo[BombenDefuseIDMilitary][i] = INVALID_PLAYER_ID;
					    	WarInfo[BombenDefuseMilitary][i] = 0;
					        return ClearAnimations(playerid);
						}
					    if(WarInfo[SprengsatzMilitaryFS][i] == 0)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Der Sprengsatz ist nicht platziert.");
					    if(WarInfo[BombenDefuseIDMilitary][i] != INVALID_PLAYER_ID)return ErrorMSG(playerid,"{DF0101}FEHLER: {FFFFFF}Eine Person entschärft bereits den Sprengsatz!");
					    ClearAnimations(playerid),OnePlayAnim(playerid, "BOMBER", "BOM_Plant", 4.0, 1,1,1,1, 0);
					    SCM(playerid,-1,"{FFFF00}INFO: {FFFFFF}Du beginnst den Sprengsatz zu entschärfen! (Dauer: 40 Sekunden)");
					    WarInfo[BombenDefuseIDMilitary][i] = playerid;
					    WarInfo[BombenDefuseMilitary][i] = (gettime()+40);
					    return 1;
					}
				}
        	}
		}
	}
	return 1;
}

stock CreateNovaeWarVehicles()
{
	WarInfo[RebelVehID][0] = CreateVehicle(522,RebelZones[WarInfo[WarZoneRebelSteps]][veh1][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh1][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh1][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh1][3], 3, 3, 60);
	WarInfo[RebelVehID][1] = CreateVehicle(560,RebelZones[WarInfo[WarZoneRebelSteps]][veh2][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh2][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh2][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh2][3], 3, 3, 60);
	WarInfo[RebelVehID][2] = CreateVehicle(560,RebelZones[WarInfo[WarZoneRebelSteps]][veh3][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh3][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh3][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh3][3], 3, 3, 60);
	WarInfo[RebelVehID][3] = CreateVehicle(487,RebelZones[WarInfo[WarZoneRebelSteps]][veh4][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh4][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh4][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh4][3], 3, 3, 60);
	WarInfo[MilitaryVehID][0] = CreateVehicle(523,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][3], 128, 128, 60);
	WarInfo[MilitaryVehID][1] = CreateVehicle(470,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][3], 128, 128, 60);
	WarInfo[MilitaryVehID][2] = CreateVehicle(470,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][3], 128, 128, 60);
	WarInfo[MilitaryVehID][3] = CreateVehicle(497,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][3], 128, 128, 60);
	return 1;
}
stock SetVehicleNovaeWarSpawn(TeamID)
{
	switch(TeamID)
	{
	    case 1:
	    {
	        for(new i;i<4;i++)if(WarInfo[MilitaryVehID][i] != INVALID_VEHICLE_ID)DestroyVehicle(WarInfo[MilitaryVehID][i]);
	        WarInfo[MilitaryVehID][0] = CreateVehicle(523,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh1][3], 128, 128, 60);
			WarInfo[MilitaryVehID][1] = CreateVehicle(470,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh2][3], 128, 128, 60);
			WarInfo[MilitaryVehID][2] = CreateVehicle(470,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh3][3], 128, 128, 60);
			WarInfo[MilitaryVehID][3] = CreateVehicle(497,MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][0], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][1], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][2], MilitaryZones[WarInfo[WarZoneMilitarySteps]][veh4][3], 128, 128, 60);
	        
		}
	    case 2:
	    {
	        for(new i;i<4;i++)if(WarInfo[RebelVehID][i] != INVALID_VEHICLE_ID)DestroyVehicle(WarInfo[RebelVehID][i]);
	        WarInfo[RebelVehID][0] = CreateVehicle(522,RebelZones[WarInfo[WarZoneRebelSteps]][veh1][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh1][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh1][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh1][3], 3, 3, 60);
			WarInfo[RebelVehID][1] = CreateVehicle(560,RebelZones[WarInfo[WarZoneRebelSteps]][veh2][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh2][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh2][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh2][3], 3, 3, 60);
			WarInfo[RebelVehID][2] = CreateVehicle(560,RebelZones[WarInfo[WarZoneRebelSteps]][veh3][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh3][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh3][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh3][3], 3, 3, 60);
			WarInfo[RebelVehID][3] = CreateVehicle(487,RebelZones[WarInfo[WarZoneRebelSteps]][veh4][0], RebelZones[WarInfo[WarZoneRebelSteps]][veh4][1], RebelZones[WarInfo[WarZoneRebelSteps]][veh4][2], RebelZones[WarInfo[WarZoneRebelSteps]][veh4][3], 3, 3, 60);
	        
		}
	}
	return 1;
}

stock DestroyNovaeWarVehicles()
{
	for(new i;i<4;i++)
	{
		if(WarInfo[RebelVehID][i] != INVALID_VEHICLE_ID)DestroyVehicle(WarInfo[RebelVehID][i]);
		if(WarInfo[MilitaryVehID][i] != INVALID_VEHICLE_ID)DestroyVehicle(WarInfo[MilitaryVehID][i]);
	}
	return 1;
}
public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}

public OnPlayerUpdate(playerid)
{
	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	return 1;
}
