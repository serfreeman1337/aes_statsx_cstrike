/*
*	AES: StatsX			     v. 0.5
*	by serfreeman1337	    http://1337.uz/
*/

#include <amxmodx>
#include <csx>
#include <csstats>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	
	#define print_team_default DontChange
	#define print_team_grey Grey
	#define print_team_red Red
	#define print_team_blue Blue
	
	#define MAX_PLAYERS 32
	#define MAX_NAME_LENGTH 32
#endif

//#define AES			// расскомментируйте для поддержки AES (http://1337.uz/advanced-experience-system/)
//#define CSSTATSX_SQL		// расскомментируйте для поддержки CSstatsX SQL (http://1337.uz/csstatsx-sql/)

#if defined AES
	#include <aes_v>
	
	native Float:aes_get_exp_for_stats_f(stats[8],stats2[4])
#endif

#if defined CSSTATSX_SQL
	#include <csstatsx_sql>
#endif

#define PLUGIN "AES: StatsX"
#define VERSION "0.5 Vega"
#define AUTHOR "serfreeman1337"

/* - CVARS - */
enum _:cvars {
	CVAR_MOTD_DESC,
	CVAR_CHAT_DESC,
	CVAR_SKILL,
	CVAR_MOTD_SKILL_FMT
}

new cvar[cvars]

/* - RANDOM STUFF */

// User stats parms id
#define STATS_KILLS             0
#define STATS_DEATHS            1
#define STATS_HS                2
#define STATS_TKS               3
#define STATS_SHOTS             4
#define STATS_HITS              5
#define STATS_DAMAGE            6

#define MAX_TOP			10

/* - SKILL - */

new const g_skill_letters[][] = {
	"L-",
	"L",
	"L+",
	"M-",
	"M",
	"M+",
	"H-",
	"H",
	"H+",
	"P-",
	"P",
	"P+",
	"G"
}

new const g_skill_class[][] = {
	"Lm",
	"L",
	"Lp",
	"Mm",
	"M",
	"Mp",
	"Hm",
	"H",
	"Hp",
	"Pm",
	"P",
	"Pp",
	"G"
}

// Global player flags.
new const BODY_PART[8][] =
{
	"WHOLEBODY", 
	"HTML_HEAD", 
	"HTML_CHEST", 
	"HTML_STOMACH", 
	"HTML_LARM", 
	"HTML_RARM", 
	"HTML_LLEG", 
	"HTML_RLEG"
}

new Float:g_skill_opt[sizeof g_skill_letters]

#define BUFF_LEN 1535

new theBuffer[BUFF_LEN + 1] = 0

#define MENU_LEN 512

new g_MenuStatus[MAX_PLAYERS + 1][2]

public SayStatsMe           = 0 // displays user's stats and rank
public SayRankStats         = 0 // displays user's rank stats
public SayRank              = 0 // displays user's rank
public SayTop15             = 0 // displays first 15 players
public SayStatsAll          = 0 // displays all players stats and rank

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say","Say_Catch")
	register_clcmd("say_team","Say_Catch")
	
	/*
	// Отображение /top15 и /rank
	// ВАЖНО! Motd окно не может показывать больше 1534-х символов, а сообщение в чат больше 192-х.
	// Если что то отображается криво или не полностью, то нужно уменьшить количество пунктов. (Топ не показывает больше 10-ти игроков)
	//   * - Ранг
	//   a - Ник (Only /top15)
	//   b - Убийста
	//   c - Смерти
	//   d - Попаданий
	//   e - Выстрелов
	//   f - В голову
	//   g - Точность
	//   h - Эффективность
	//   i - Скилл
	//   j - Звание Army Ranks
	//   k - K:D
	//   l - HS:K
	//   m - HS %
	//   n - онлайн время
	*/
	
	cvar[CVAR_MOTD_DESC] = register_cvar("aes_statsx_top","*abcfi")
	cvar[CVAR_CHAT_DESC] = register_cvar("aes_statsx_rank","bci")
	
	// Настройка скилла. Значения схожи со значениями эффективности.
	// Значения: L- L L+ M- M M+ H- H H+ P- P P+ G
	cvar[CVAR_SKILL] = register_cvar("aes_statsx_skill","60.0 75.0 85.0 100.0 115.0 130.0 140.0 150.0 165.0 180.0 195.0 210.0")
	
	/*
	* Как выводить скилл в motd
	*	0 - html (картинка с буквой + скилл)
	*	1 - буква (скилл)
	*	2 - буква
	*	3 - скилл
	*/
	cvar[CVAR_MOTD_SKILL_FMT] = register_cvar("aes_statsx_motd_skill","0")
	
	register_dictionary("statsx.txt")
	register_dictionary("statsx_aes.txt")
	
	register_menucmd(register_menuid("Stats Menu"), 1023, "actionStatsMenu")
}

public plugin_cfg(){
	new levelString[512],stPos,ePos,rawPoint[20],cnt
	get_pcvar_string(cvar[CVAR_SKILL],levelString,charsmax(levelString))
	
	// парсер значений для скилла
	do {
		ePos = strfind(levelString[stPos]," ")
		
		formatex(rawPoint,ePos,levelString[stPos])
		g_skill_opt[cnt] = str_to_float(rawPoint)
		
		stPos += ePos + 1
		
		cnt++
		
		// narkoman wole suka
		if(cnt > sizeof g_skill_letters - 1)
			break
	} while (ePos != -1)
}

// Ловим сообщения чата
public Say_Catch(id){
	new msg[191]
	read_args(msg,190)
	
	trim(msg)
	remove_quotes(msg)

	if(msg[0] == '/'){
		if(strcmp(msg[1],"rank",1) == 0)
		{
			return RankSay(id)
		}
		
		if(containi(msg[1],"top") == 0)
		{
			replace(msg,190,"/top","")
			
			return SayTop(id,str_to_num(msg))
		}
		if(strcmp(msg[1],"rankstats",1) == 0)
		{
			return RankStatsSay(id,id)
		}
		
		if(strcmp(msg[1],"statsme",1) == 0)
		{
			return StatsMeSay(id,id)
		}
		
		if(strcmp(msg[1],"stats",1) == 0)
		{
			arrayset(g_MenuStatus[id],0,2)
			return ShowStatsMenu(id,0)
		}
	}
	
	return PLUGIN_CONTINUE
}

//
// Команда /rank
//
public RankSay(id){
	// команда /rank выключена
	if(!SayRank)
	{
		client_print_color(id,print_team_red,"%L %L",id,"STATS_TAG", id,"DISABLED_MSG")
		
		return PLUGIN_HANDLED
	}
	
	new message[191],len,rank,stats_num,stats[8],bh[8]
	
	len += formatex(message[len],charsmax(message)- len,"%L ",id,"STATS_TAG")
	
	#if defined CSSTATSX_SQL
		rank = get_user_stats_sql(id,stats,bh)
		stats_num = get_statsnum_sql()
	#else
		rank = get_user_stats(id,stats,bh)
		stats_num = get_statsnum()
	#endif
	
	len += formatex(message[len],charsmax(message) - len,"%L ",id,"AES_YOUR_RANK_IS",rank,stats_num)
	len += parse_rank_desc(id,message[len],charsmax(message)-len,stats)
	
	client_print_color(id,print_team_default,message)
	
	return PLUGIN_HANDLED
}

//
// Формирование сообщения /rank
//
parse_rank_desc(id,msg[],maxlen,stats[8]){
	new cnt,theChar[4],len
	
	new desc_str[10]
	get_pcvar_string(cvar[CVAR_CHAT_DESC],desc_str,charsmax(desc_str))
	
	// Проверяем всё флаги
	for(new i,length = strlen(desc_str) ; i < length ; ++i){
		theChar[0] = desc_str[i]	// фз почему напрямую не рабатает
		
		// если это первое значение, то рисуем в начале скобку, иначе запятую с пробелом
		if(cnt != length)
			len += formatex(msg[len],maxlen - len,cnt <= 0 ? "(" : ", ")
		
		// добавляем в сообщение информацию в соотв. с флагами
		switch(theChar[0]){
			 // убийства
			case 'b':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%d^1",id,"KILLS",stats[0])
			}
			 // смерти
			case 'c':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%d^1",id,"DEATHS",stats[1])
			}
			 // попадания
			case 'd':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%d^1",id,"HITS",stats[5])
			}
			// выстрелы
			case 'e':
			{ 
				len += formatex(msg[len],maxlen - len,"%L ^3%d^1",id,"SHOTS",stats[4])
			}
			// хедшоты
			case 'f':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%d^1",id,"STATS_HS",stats[2])
			}
			// точность
			case 'g':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%.2f%%^1",id,"ACC",accuracy(stats))
			}
			// эффективность
			case 'h':
			{ 
				len += formatex(msg[len],maxlen - len,"%L ^3%d%%^1",id,"EFF",effec(stats))
			}
			// скилл
			case 'i':
			{
				new Float:skill,skill_id
				
				#if defined CSSTATSX_SQL
					get_user_skill(id,skill)
				#else
					skill = effec(stats)
				#endif
				
				skill_id = aes_statsx_get_skill_id(skill)
				
				len += formatex(msg[len],maxlen - len,"%L ^3%s^1 (%.2f)",id,"STATS_SKILL",
					g_skill_letters[skill_id],
					skill
				)
				
			}
			#if defined AES
			case 'j':{ // ранг и опыт
				new Float:player_exp = aes_get_player_exp(id)
				
				if(player_exp == -1.0)// без ранга
				{
					len += formatex(msg[len],maxlen - len,"%L ^4---^1",id,"STATS_RANK")
				}
				else
				{
					new level_str[AES_MAX_LEVEL_LENGTH ]
					new player_level = aes_get_player_level(id)
					aes_get_level_name(player_level,level_str,charsmax(level_str),id)
					
					len += formatex(msg[len],maxlen - len,"%L ^3%L^1",id,"STATS_RANK",id,"AES_RANK",
						level_str,player_exp
					)
				}
			}
			#endif
			// K:D
			case 'k':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%.2f^1",
					id,"AES_KS",
					kd_ratio(stats)
				)
			}
			// HS:K
			case 'l':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%.2f^1",
					id,"AES_HSK",
					hsk_ratio(stats)
				)
			}
			// HS effec
			case 'm':
			{
				len += formatex(msg[len],maxlen - len,"%L ^3%.2f^1%%",
					id,"AES_HSP",
					effec_hs(stats)
				)
			}
			// время в игре
			case 'n':
			{
			}
		}
		
		theChar[0] = 0
		cnt ++
	}
	
	// завершаем всё сообщение скобкой, если была подстановка параметров
	if(cnt)
	{
		len += formatex(msg[len],maxlen - len,")")
	}
	
	return len
}

//
// Формирование окна /rankstats
// 	id - кому показывать
// 	player_id - кого показывать
//
public RankStatsSay(id,player_id){
	// Команда /rankstats выключена
	if(!SayRankStats)
	{
		client_print_color(id,print_team_default,"%L %L",id,"STATS_TAG", id,"DISABLED_MSG")
		
		return PLUGIN_HANDLED
	}
	
	new len,motd_title[MAX_NAME_LENGTH]
	new name[MAX_NAME_LENGTH],rank,stats[8],bh[8],stats_num,Float:skill,skill_id,skill_str[64]
	
	theBuffer[0] = 0
	
	formatex(motd_title,charsmax(motd_title),"%L",id,"RANKSTATS_TITLE")
	
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L",id,"HTML_META")
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L",id,"HTML_STYLE")
	
	#if defined CSSTATSX_SQL
		rank = get_user_stats_sql(player_id,stats,bh)
		stats_num = get_statsnum_sql()
		get_user_skill(player_id,skill)
	#else
		rank = get_user_stats(player_id,stats,bh)
		stats_num = get_statsnum()
		skill = effec(stats)
	#endif
	
	skill_id = aes_statsx_get_skill_id(skill)
	
	
	if(id == player_id)
	{
		formatex(name,charsmax(name),"%L",id,"HTML_YOU")
	}
	else
	{
		get_user_name(player_id,name,charsmax(name))
	}
	
	switch(get_pcvar_num(cvar[CVAR_MOTD_SKILL_FMT]))
	{
		// html
		case 0:
		{
			formatex(skill_str,charsmax(skill_str),"%L",
				id,
				"HTML_SKILL_FMT",
				
				g_skill_class[skill_id],
				skill
			)
		}
		// буква (скилл)
		case 1:
		{
			formatex(skill_str,charsmax(skill_str),"%s (%.2f)",
				g_skill_letters[skill_id],
				skill
			)
		}
		// буква
		case 2:
		{
			formatex(skill_str,charsmax(skill_str),"%s",
				g_skill_letters[skill_id]
			)
		}
		// скилл
		case 3:
		{
			formatex(skill_str,charsmax(skill_str),"%.2f",
				skill
			)
		}
	}
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<table cellspacing=10 cellpadding=0><tr>")
	
	//
	// Общая статистика
	//
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<td valign=top width=50%% class=q><table cellspacing=0><tr><th colspan=2>")
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",
		id,"HTML_RANKSTATS_TSTATS",
		name,rank,stats_num
	)
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%d (%L %d)",id,"HTML_KILLS",stats[STATS_KILLS],id,"HTML_HS",stats[STATS_HS])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%d",id,"HTML_DEATHS",stats[STATS_DEATHS])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%d",id,"HTML_HITS",stats[STATS_HITS])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%d",id,"HTML_SHOTS",stats[STATS_SHOTS])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%d",id,"HTML_DMG",stats[STATS_DAMAGE])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%.2f%%",id,"HTML_ACC",accuracy(stats))
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%.2f%%",id,"HTML_EFF",effec(stats))
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%s",id,"HTML_SKILL",skill_str)
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td height=18px><td>")
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"</td></tr></table></td>")
	
	//
	// Статистика по попаданиям
	//
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<td valign=top width=50%% class=q><table cellspacing=0><tr><th colspan=2>")
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",id,"HTML_RANKSTATS_THITS")
		
	new theSwitcher
		
	for (new i = 1; i < 8; i++)
	{
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=%s><td>%L<td>%d",
			theSwitcher ? "b" : "q",
			id,BODY_PART[i],bh[i]
		)
			
		theSwitcher = theSwitcher ? false : true
	}
	
	// mne tak nadoel etot kod :(
	for(new i = 0 ; i < 2; ++i){
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=%s><td height=18px><td>",theSwitcher ? "b" : "q")
			
		theSwitcher = theSwitcher ? false : true
	}
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"</td>")
	
	show_motd(id,theBuffer,motd_title)
	
	return PLUGIN_HANDLED
}


//
// Личная статистка за карту
// 
// id - кому показывать
// stId - кого показывать
public StatsMeSay(id,player_id){
	if(!SayStatsMe){
		client_print_color(id,0,"%L %L",id,"STATS_TAG", id,"DISABLED_MSG")
		
		return PLUGIN_HANDLED
	}
	
	new len,stats[8],bh[8],motd_title[64]
	
	formatex(motd_title,charsmax(motd_title),"%L",id,"STATS_TITLE")
	
	if(id != player_id){
		new name[32]
		get_user_name(player_id,name,charsmax(name))
	}
	
	theBuffer[0] = 0
	
	get_user_wstats(player_id,0,stats,bh)
	
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L%L",id,"HTML_META",id,"HTML_STYLE")
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L",id,"HTML_STATS_BODY")
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<table cellspacing=10 cellpadding=0><tr>")
	
	len += formatex(theBuffer[len],BUFF_LEN-len,"<td valign=top width=20%% class=q><table cellspacing=0 width=100%%><tr><th colspan=2>%L<tr><td>%L<td>%d<tr class=b><td>%L<td>%d<tr><td>%L<td>%d<tr class=b><td>%L<td>%d<tr><td>%L<td>%d<tr class=b><td>%L<td>%d<tr><td>%L<td>%0.2f%%<tr class=b><td>%L<td>%0.2f%%</table>",
		id,"HTML_STATS_HEADER1",
		id,"HTML_KILLS",stats[STATS_KILLS],
		id,"HTML_HS",stats[STATS_HS],
		id,"HTML_DEATHS",stats[STATS_DEATHS],
		id,"HTML_HITS",stats[STATS_HITS],
		id,"HTML_SHOTS",stats[STATS_SHOTS],
		id,"HTML_DMG",stats[STATS_DAMAGE],
		id,"HTML_ACC",accuracy(stats),
		id,"HTML_EFF",effec(stats))
		
	len += formatex(theBuffer[len],BUFF_LEN-len,"<td valign=top width=80%% class=q><table cellspacing=0 width=100%%><tr><th>%L<th>%L<th>%L<th>%L<th>%L<th>%L<th>%L",
		id,"HTML_WEAPON",
		id,"HTML_KILLS",
		id,"HTML_DEATHS",
		id,"HTML_HITS",
		id,"HTML_SHOTS",
		id,"HTML_DMG",
		id,"HTML_ACC"
	)
		
	new bool:odd
		
	for (new wpnName[32],wpnId = 1 ; wpnId < xmod_get_maxweapons() && charsmax(theBuffer)-len > 0 ; wpnId++)
	{
		if (get_user_wstats(player_id, wpnId, stats,bh))
		{
			xmod_get_wpnname(wpnId,wpnName,charsmax(wpnName))
			
			len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=%s><td>%s<td>%d<td>%d<td>%d<td>%d<td>%d<td>%0.1f%%",
				odd ? "b" : "q",
				wpnName,
				stats[STATS_KILLS],
				stats[STATS_DEATHS],
				stats[STATS_HITS],
				stats[STATS_SHOTS],
				stats[STATS_DAMAGE],
				accuracy(stats)
			)
				
			odd ^= true
		}
	}
		
	show_motd(id,theBuffer,motd_title)
	
	return PLUGIN_HANDLED
}

// Формирование окна /top
// В Pos указывается с какой позиции рисовать
public SayTop(id,Pos)
{
	if(!SayTop15){
		client_print_color(id,0,"%L %L",id,"STATS_TAG", id,"DISABLED_MSG")
		
		return PLUGIN_HANDLED
	}
	
	if(Pos == 15 || Pos <= 0)
		Pos = 10
		
	#if defined CSSTATSX_SQL
		if(!get_stats_sql_thread(id,Pos,MAX_TOP,"SayTopHandler"))
		{
			client_print_color(id,print_team_red,"%L %L",id,"STATS_TAG",id,"AES_STATS_INFO1")
		}
		
		server_print("--> CALLED TOP HANDLER")
	#else
		SayTopHandler(id,Pos)
	#endif
	
	return PLUGIN_HANDLED
}

enum _:stats_former_array
{
	STATSF_NAME[MAX_NAME_LENGTH],
	STATSF_AUTHID[30],
	STATSF_DATA[8],
	STATSF_DATA2[4],
	STATSF_BH[8],
	STATSF_RANK
}

//
// Сбор статистики
//
public SayTopHandler(id,Pos)
{
	server_print("--> TOP HANDLER RETURN %d %d",id,Pos)
	
	new Array:stats_array = ArrayCreate(stats_former_array)
	new stats_info[stats_former_array],last_rank
	
	#if defined CSSTATSX_SQL
		new size = min(get_statsnum_sql(),Pos)
	#else
		new size = min(get_statsnum(),Pos)
	#endif
	
	#if defined AES
		new Array:authids_array = ArrayCreate(sizeof stats_info[STATSF_AUTHID])
	#endif
	
	new rank,stats[8],stats2[4],bh[8],name[MAX_NAME_LENGTH],authid[30]
	
	for(new i = size - MAX_TOP < 0 ? 0 : size - MAX_TOP; i < size ; i++){
		#if defined CSSTATSX_SQL
			rank = get_stats_sql(i,stats,bh,name,charsmax(name),authid,charsmax(authid))
		#else
			rank = get_stats(i,stats,bh,name,charsmax(name),authid,charsmax(authid))
			get_stats2(i,stats2)
		#endif
		
		if(!rank)
			rank = last_rank
			
		for(new i ; i < 8 ; i++)
		{
			stats_info[STATSF_DATA][i] = stats[i]
			stats_info[STATSF_BH][i] = bh[i]
		}
		
		for(new i ; i < 4 ; i++)
		{
			stats_info[STATSF_DATA2][i] = stats2[i]
		}
		
		copy(stats_info[STATSF_NAME],
			charsmax(stats_info[STATSF_NAME]),
			name
		)
		
		copy(stats_info[STATSF_AUTHID],
			charsmax(stats_info[STATSF_AUTHID]),
			authid
		)
		
		last_rank = rank
		stats_info[STATSF_RANK] = rank
		
		// формируем статистику
		ArrayPushArray(stats_array,stats_info)
		
		#if defined AES
			ArrayPushString(authids_array,authid)
		#endif
	}
	
	new stats_data[2]
	
	stats_data[0] = _:stats_array
	
	#if defined AES
		stats_data[1] = _:authids_array
		
		if(!aes_find_stats_thread(id,authids_array,"SayTopFormer",stats_data,sizeof stats_data))
		{
			new Array:empty_aes_stats = ArrayCreate()
			SayTopFormer(id,empty_aes_stats,stats_data)
		}
	#else
		SayTopFormer(id,stats_data)
	#endif
}

aes_statsx_get_skill_id(Float:skill)
{	
	for(new i ; i < sizeof g_skill_opt ; i++)
	{
		if(skill < g_skill_opt[i])
		{
			return i
		}
	}
	
	return 0
}

#if !defined AES
public SayTopFormer(id,stats_data[])
#else
public SayTopFormer(id,Array:aes_stats_array,stats_data[])
#endif
{
	server_print("-FFF-> %d %d %d",
		id,
		stats_data[0],
		stats_data[1]
	)
	
	theBuffer[0] = 0
	
	new Array:stats_array = Array:stats_data[0]
	
	new len,title[64]
	formatex(title,charsmax(title),"%L",id,"HMTL_PLAYER_TOP")
	
	// заголовок
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"HTML_META")
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"HTML_STYLE")
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"HTML_TOP_BODY",id,"HTML_PLAYER_TOP")
	
	// таблица со статистикой
	new stats_info[stats_former_array],row_str[512],cell_str[MAX_NAME_LENGTH * 3],row_len
	new desc_str[10],desc_char[4],bool:odd
	
	get_pcvar_string(cvar[CVAR_MOTD_DESC],desc_str,charsmax(desc_str))
	trim(desc_str)
	
	new desc_length = strlen(desc_str)
	new skill_out = get_pcvar_num(cvar[CVAR_MOTD_SKILL_FMT])
	
	len += parse_top_desc_header(id,theBuffer,BUFF_LEN,len,false,desc_str)
	
	#if defined AES
		new aes_stats_size = ArraySize(aes_stats_array)
		new aes_last_iter
	#endif
	
	for(new stats_index,length = ArraySize(stats_array);stats_index < length; stats_index ++){
		ArrayGetArray(stats_array,stats_index,stats_info)
		
		for(new desc_index ; desc_index < desc_length ; desc_index++)
		{
			cell_str[0] = 0
			desc_char[0] = desc_str[desc_index]
			
			switch(desc_char[0]){
				// ранк
				case '*':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats_info[STATSF_RANK])
				}
				// ник
				case 'a':
				{
					formatex(cell_str,charsmax(cell_str),"%s",stats_info[STATSF_NAME])
					
					replace_all(cell_str,charsmax(cell_str),"<","&lt")
					replace_all(cell_str,charsmax(cell_str),">","&gt")
				}
				// убийства
				case 'b':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats_info[STATSF_DATA][STATS_KILLS])
				}
				// смерти
				case 'c':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats_info[STATSF_DATA][STATS_DEATHS])
				}
				// попадания
				case 'd':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats_info[STATSF_DATA][STATS_HITS])
				}
				// выстрелы
				case 'e':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats_info[STATSF_DATA][STATS_SHOTS])
				}
				// хедшоты
				case 'f':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats_info[STATSF_DATA][STATS_HS])
				}
				// точнсть
				case 'g':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						accuracy(stats_info[STATSF_DATA])
					)
				}
				// эффективность
				case 'h':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						effec(stats_info[STATSF_DATA])
					)
				}
				
				// скилл
				case 'i':{
					new Float:skill ,skill_id
					
					#if defined CSSTATSX_SQL
						// используем скилл из csstatsx sql (ELO)
						get_skill(stats_info[STATSF_RANK] - 1,skill)
					#else
						// используем K:D для скилла
						skill = effec(stats_info[STATSF_DATA])
					#endif
					
					skill_id =  aes_statsx_get_skill_id(skill)
					
					switch(skill_out)
					{
						// html
						case 0:
						{
							formatex(cell_str,charsmax(cell_str),"%L",
								id,
								"HTML_SKILL_FMT",
								
								
								g_skill_class[skill_id],
								skill
							)
						}
						// буква (скилл)
						case 1:
						{
							formatex(cell_str,charsmax(cell_str),"%s (%.2f)",
								g_skill_letters[skill_id],
								skill
							)
						}
						// буква
						case 2:
						{
							formatex(cell_str,charsmax(cell_str),"%s",
								g_skill_letters[skill_id]
							)
						}
						// скилл
						case 3:
						{
							formatex(cell_str,charsmax(cell_str),"%.2f",
								skill
							)
						}
					}
					
					
					
					
				}
				#if defined AES
				// опыт и ранг
				case 'j':
				{
					new aes_stats[aes_stats_struct]
					
					if(aes_stats_size && aes_stats_size > aes_last_iter)
						ArrayGetArray(aes_stats_array,aes_last_iter,aes_stats)
					
					// не нашли стату aes для этого игрока
					if((strcmp(aes_stats[AES_S_STEAMID],stats_info[STATSF_AUTHID]) != 0 &&
						strcmp(aes_stats[AES_S_NAME],stats_info[STATSF_AUTHID]) != 0 &&
						strcmp(aes_stats[AES_S_IP],stats_info[STATSF_AUTHID]) != 0)
					)
					{
						// расчитываем на основе статы cstrike
						new stats[8],stats2[4]
						
						// кек
						for(new i ; i < 8 ; i++)
						{
							stats[i] = stats_info[STATSF_DATA][i]
						}
						
						for(new i ; i < 4 ; i++)
						{
							stats2[i] = stats_info[STATSF_DATA2][i]
						}
						
						new Float:exp = aes_get_exp_for_stats_f(stats,stats2)
						
						if(exp != -1.0)
						{
							new level = aes_get_exp_level(exp)
							
							new level_str[AES_MAX_LEVEL_LENGTH]
							aes_get_level_name(level,level_str,charsmax(level_str),id)
							
							formatex(cell_str,charsmax(cell_str),"%L",
								id,"AES_RANK",
								level_str,
								exp + 0.005
							)
						}
						else // расчет по стате выключен
						{
							formatex(cell_str,charsmax(cell_str),"-")
						}
					}
					else
					{
						new level_str[AES_MAX_LEVEL_LENGTH]
						aes_get_level_name(aes_stats[AES_S_LEVEL],level_str,charsmax(level_str),id)
						
						formatex(cell_str,charsmax(cell_str),"%L",
							id,"AES_RANK",
							level_str,
							aes_stats[AES_S_EXP] + 0.005
						)
						
						aes_last_iter ++
					}
				}
				#endif
				// K:D
				case 'k':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f",
						kd_ratio(stats_info[STATSF_DATA])
					)
				}
				// HS:K
				case 'l':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f",
						hsk_ratio(stats_info[STATSF_DATA])
					)
				}
				// HS effec
				case 'm':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						effec_hs(stats_info[STATSF_DATA])
					)
				}
				// время в игре
				#if defined CSSTATSX_SQL
				case 'n':
				{
				}
				#endif
				default: continue
			}
			
			// выводим отформатированные данные
			row_len += formatex(row_str[row_len],charsmax(row_str)-row_len,"%L",id,"HTML_BODY_CELL",cell_str)
		}
		
		row_len = 0
		
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",id,"HTML_BODY_ROW",odd ? " id=b" : " id=q",row_str)
		odd ^= true
	}
	
	ArrayDestroy(stats_array)
	
	#if defined AES
		ArrayDestroy(Array:stats_data[1])
		ArrayDestroy(aes_stats_array)
	#endif
	
	show_motd(id,theBuffer)
	
	write_file("tt.html",theBuffer,0)
}

// Stats formulas
Float:accuracy(izStats[])
{
	if (!izStats[STATS_SHOTS])
		return (0.0)
	
	return (100.0 * float(izStats[STATS_HITS]) / float(izStats[STATS_SHOTS]))
}

Float:effec(izStats[])
{
	if (!izStats[STATS_KILLS])
		return (0.0)
	
	return (100.0 * float(izStats[STATS_KILLS]) / float(izStats[STATS_KILLS] + izStats[STATS_DEATHS]))
}

Float:effec_hs(stats[])
{
	if (!stats[STATS_KILLS])
		return float(stats[STATS_HS])
	
	return (100.0 * float(stats[STATS_HS]) / float(stats[STATS_KILLS] + stats[STATS_HS]))
}

Float:kd_ratio(stats[])
{
	if(!stats[STATS_DEATHS])
	{
		return float(stats[STATS_KILLS])
	}
	
	return float(stats[STATS_KILLS]) / float(stats[STATS_DEATHS])
}

Float:hsk_ratio(stats[])
{
	if(!stats[STATS_KILLS])
	{
		return float(stats[STATS_HS])
	}
	
	return float(stats[STATS_HS]) / float(stats[STATS_KILLS])
}


// Формируем заголовок таблицы для топа игроков
parse_top_desc_header(id,buff[],maxlen,len,bool:isAstats,desc_str[]){
	new tmp[256],len2,theChar[4],lCnt
	
	lCnt = isAstats != true ? strlen(desc_str) : 0//strlen(aStatsDescCap)
	
	for(new i ; i < lCnt ; ++i){
		theChar[0] = isAstats != true ? desc_str[i] : desc_str[i]//aStatsDescCap[i]
		
		switch(theChar[0]){
			case '*':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_POS")
			}
			case 'a':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_PLAYER")
			}
			case 'b':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_KILLS")
			}
			case 'c':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_DEATHS")
			}
			case 'd':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_HITS")
			}
			case 'e':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_SHOTS")
			}
			case 'f':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_HS")
			}
			case 'g':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_ACC")
			}
			case 'h':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_EFF")
			}
			case 'i':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_SKILL")
			}
			#if !defined NO_AES
			case 'j':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_ARMYRANKS")
			}
			#endif
			case 'k':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_KS")
			}
			case 'l':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_HSK")
			}
			case 'm':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_HSP")
			}
			#if defined CSSTATSX_SQL
			case 'n':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"HTML_HEADER_CELL","",id,"HTML_TIME")
			}
			#endif
		}
		
		theChar[0] = 0
	}
	
	return formatex(buff[len],maxlen-len,"%L",id,"HTML_TOP_HEADER_ROW",tmp)
}

// формирование меню для просмотра статистики игроков
public ShowStatsMenu(id,page){
	if(!SayStatsAll){
		client_print_color(id,0,"%L %L",id,"STATS_TAG", id,"DISABLED_MSG")
		
		return PLUGIN_HANDLED
	}
	
	new menuKeys,menuText[512],menuLen
	new tName[42],players[32],pCount
	
	get_players(players,pCount)
	
	new maxPages = ((pCount - 1) / 7) + 1 // находим макс. кол-во страниц
	
	// отображаем с начала, если такой страницы не существует
	if(page > maxPages)
		page = 0

	// начальный индекс игрока согласно странице
	new usrIndex = (7 * page)
	
	menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"%L %L\R\y%d/%d^n",
		id,"MENU_TAG",id,"MENU_TITLE",page + 1,maxPages)
	
	// добавляем игроков в меню
	while(usrIndex < pCount){
		get_user_name(players[usrIndex],tName,31)
		menuKeys |= (1 << usrIndex % 7)
		
		menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n\r%d.\w %s",
			(usrIndex % 7) + 1,tName)
		
		usrIndex ++
		
		// перываем заполнение
		// если данная страница уже заполнена
		if(!(usrIndex % 7))
			break
	}
	
	// вариант просмотра статистики
	menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n^n\r%d.\w %L",8,id,g_MenuStatus[id][0] ? "MENU_RANK" : "MENU_STATS")
	menuKeys |= MENU_KEY_8
	
	if(!(usrIndex % 7)){
		menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n^n\r%d.\w %L",9,id,"MORE")
		menuKeys |= MENU_KEY_9
	}
	
	if((7 * page)){
		menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n^n\r%d.\w %L",0,id,"BACK")
		menuKeys |= MENU_KEY_0
	}else{
		menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n^n\r%d.\w %L",0,id,"EXIT")
		menuKeys |= MENU_KEY_0
	}
			
	
	show_menu(id,menuKeys,menuText,-1,"Stats Menu")
	
	return PLUGIN_HANDLED
}

public actionStatsMenu(id,key){
	switch(key){
		case 0..6:{
			new usrIndex = key + (7 * g_MenuStatus[id][1]) + 1
			
			if(!is_user_connected(id)){
				ShowStatsMenu(id,g_MenuStatus[id][1])
				
				return PLUGIN_HANDLED
			}
				
			g_MenuStatus[id][0] ? RankStatsSay(id,usrIndex) : StatsMeSay(id,usrIndex)
			
			ShowStatsMenu(id,g_MenuStatus[id][1])
		}
		case 7:{
			g_MenuStatus[id][0] = g_MenuStatus[id][0] ? 0 : 1
			ShowStatsMenu(id,g_MenuStatus[id][1])
		}
		case 8:{
			g_MenuStatus[id][1] ++
			ShowStatsMenu(id,g_MenuStatus[id][1])
		}
		case 9:{
			if(g_MenuStatus[id][1]){
				g_MenuStatus[id][1] --
				ShowStatsMenu(id,g_MenuStatus[id][1])
			}
		}
	}
	
	return PLUGIN_HANDLED
}
