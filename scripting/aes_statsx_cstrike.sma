/*
*	AES: StatsX			     v. 0.5
*	by serfreeman1337	    http://1337.uz/
*/

#include <amxmodx>
#include <csx>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	
	#define print_team_default DontChange
	#define print_team_grey Grey
	#define print_team_red Red
	#define print_team_blue Blue
	
	#define MAX_PLAYERS 32
	#define MAX_NAME_LENGTH 32
	
	#define client_disconnected client_disconnect
#endif

//#define AES			// расскомментируйте для поддержки AES (http://1337.uz/advanced-experience-system/)
//#define CSSTATSX_SQL		// расскомментируйте для поддержки CSstatsX SQL (http://1337.uz/csstatsx-sql/)

#if defined AES
	#include <aes_v>
	
	native Float:aes_get_exp_for_stats_f(stats[8],stats2[4])
#endif

#if defined CSSTATSX_SQL
	#include <csstatsx_sql>
	#include <time>
#endif

#define PLUGIN "AES: StatsX"
#define VERSION "0.5 Vega"
#define AUTHOR "serfreeman1337"

/* - CVARS - */
enum _:cvars {
	CVAR_MOTD_DESC,
	CVAR_CHAT_DESC,
	CVAR_SESTATS_DESC,
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
	"AES_HEAD", 
	"AES_CHEST", 
	"AES_STOMACH", 
	"AES_LARM", 
	"AES_RARM", 
	"AES_LLEG", 
	"AES_RLEG"
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
public SayHot	= 0	// displays top from current players
#if defined CSSTATSX_SQL
public SaySeStats	= 0 // displays players match history
#endif

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
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
	
	//
	// o - изменение скилла
	// p - дата сессии
	// q - карта
	//
	cvar[CVAR_SESTATS_DESC] = register_cvar("aes_statsx_sestats","poqnbckfl")
	
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
	
	#if defined CSSTATSX_SQL
		register_dictionary("time.txt")
	#endif
}

public plugin_init()
{
	register_clcmd("say","Say_Catch")
	register_clcmd("say_team","Say_Catch")
	
	register_menucmd(register_menuid("Stats Menu"), 1023, "actionStatsMenu")
}

#if AMXX_VERSION_NUM < 183
	public plugin_cfg()
#else
	public OnConfigsExecuted()
#endif
{
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
	
	new addStast[] = "amx_statscfg add ^"%s^" %s"

	server_cmd(addStast, "ST_SAY_STATSME", "SayStatsMe")
	server_cmd(addStast, "ST_SAY_RANKSTATS", "SayRankStats")
	server_cmd(addStast, "ST_SAY_RANK", "SayRank")
	server_cmd(addStast, "ST_SAY_TOP15", "SayTop15")
	server_cmd(addStast, "ST_SAY_STATS", "SayStatsAll")
	server_cmd(addStast, "AES_SAY_HOT", "SayHot")
	
	#if defined CSSTATSX_SQL 
		server_cmd(addStast, "CSXSQL_SESTATS_CFG", "SaySeStats")
	#endif
}

#if defined CSSTATSX_SQL
//
// Команда /sestats
//
public SeStats_Show(id,player_id)
{
	if(!SaySeStats)
	{
		client_print_color(id,print_team_red,"%L %L",id,"STATS_TAG", id,"DISABLED_MSG")
		
		return PLUGIN_HANDLED
	}
	
	new plr_db,sestats_data[2]
	
	sestats_data[0] = id
	sestats_data[1] = player_id
	
	plr_db = get_user_stats_id(player_id)
	
	if(!plr_db|| !get_sestats_thread_sql(plr_db,"SeStats_ShowHandler",sestats_data,sizeof sestats_data,10))
	{
		client_print_color(id,print_team_red,"%L %L",id,"STATS_TAG", id,"AES_STATS_INFO2")
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_HANDLED
}

public SeStats_ShowHandler(CSXSQL_SESTATS:sestats_array,sestats_data[])
{
	new id = sestats_data[0]
	new player_id = sestats_data[1]
	
	if(!is_user_connected(id) || !is_user_connected(player_id))
	{
		get_sestats_free(sestats_array)
		return PLUGIN_HANDLED
	}
	
	new len,title[64]
	
	// заголовок
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_META")
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_STYLE")
	
	if(id == player_id)
	{
		formatex(title,charsmax(title),"%L %L",
			id,"YOURS",
			id,"CSXSQL_SETITLE"
		)
			
	}
	else
	{
		new name[MAX_NAME_LENGTH]
		get_user_name(player_id,name,charsmax(name))
		
		formatex(title,charsmax(title),"%L %s",
			id,"CSXSQL_SETITLE",
			name
		)
	}
	
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"CSXSQL_SEHTML",title)
	
	// таблица со статистикой
	new row_str[512],cell_str[MAX_NAME_LENGTH * 3],row_len
	new desc_str[10],desc_char[4],bool:odd
	
	get_pcvar_string(cvar[CVAR_SESTATS_DESC],desc_str,charsmax(desc_str))
	trim(desc_str)
	
	new desc_length = strlen(desc_str)
	
	len += parse_top_desc_header(id,theBuffer,BUFF_LEN,len,false,desc_str)
	
	new stats[8],bh[8]
	
	for(new i,length = get_sestats_read_count(sestats_array) ; i < length ; i++)
	{
		get_sestats_read_stats(sestats_array,i,stats,bh)
		
		for(new desc_index ; desc_index < desc_length ; desc_index++)
		{
			cell_str[0] = 0
			desc_char[0] = desc_str[desc_index]
			
			switch(desc_char[0])
			{
				// время
				case 'p':
				{
					new stime = get_sestats_read_stime(sestats_array,i)
					format_time(cell_str,charsmax(cell_str),"%m/%d/%Y - %H:%M:%S",stime)
				}
				// изменение скилла
				case 'o':
				{
					new Float:skill = get_sestats_read_skill(sestats_array,i)
					
					formatex(cell_str,charsmax(cell_str),"%s%.2f",
						skill > 0.0 ? "+" : "",
						skill
					)
				}
				// карта
				case 'q':
				{
					get_sestats_read_map(sestats_array,i,cell_str,charsmax(cell_str))
				}
				// убийства
				case 'b':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_KILLS])
				}
				// смерти
				case 'c':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_DEATHS])
				}
				// попадания
				case 'd':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_HITS])
				}
				// выстрелы
				case 'e':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_SHOTS])
				}
				// хедшоты
				case 'f':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_HS])
				}
				// точнсть
				case 'g':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						accuracy(stats)
					)
				}
				// эффективность
				case 'h':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						effec(stats)
					)
				}
				// K:D
				case 'k':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f",
						kd_ratio(stats)
					)
				}
				// HS:K
				case 'l':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f",
						hsk_ratio(stats)
					)
				}
				// HS effec
				case 'm':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						effec_hs(stats)
					)
				}
				// время в игре
				case 'n':
				{
					new ot = get_sestats_read_online(sestats_array,i)
					func_format_ot(ot,cell_str,charsmax(cell_str),id)
				}
				default: continue
			}
			
			// выводим отформатированные данные
			row_len += formatex(row_str[row_len],charsmax(row_str)-row_len,"%L",id,"AES_BODY_CELL",cell_str)
		}
		row_len = 0
		
		row_len = len
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",id,"AES_BODY_ROW",odd ? " id=b" : " id=q",row_str)
		
		if(len >= BUFF_LEN)
		{
			theBuffer[row_len] = 0
			break
		}
		
		row_len = 0
		
		odd ^= true
	}
	
	get_sestats_free(sestats_array)
	
	formatex(title,charsmax(title),"%L",id,"CSXSQL_SETITLE")
	show_motd(id,theBuffer,title)
	
	return PLUGIN_HANDLED
}
#endif

//
// Команда /hot
//
public ShowCurrentTop(id)
{
	if(!SayHot)
	{
		client_print_color(id,print_team_red,"%L %L",id,"STATS_TAG", id,"DISABLED_MSG")
		
		return PLUGIN_HANDLED
	}
	
	new players[MAX_PLAYERS],pnum
	get_players(players,pnum)
	
	new current_top[MAX_PLAYERS][2]
	
	for(new i,stats[8],bh[8] ; i < pnum ; i++)
	{
		current_top[i][0] = players[i]
		
		#if !defined CSSTATSX_SQL
			current_top[i][1] = get_user_stats(players[i],stats,bh)
		#else
			current_top[i][1] = get_user_stats_sql(players[i],stats,bh)
		#endif
	}
	
	SortCustom2D(current_top,sizeof current_top,"Sort_CurrentTop")
	
	new len,title[64]
	formatex(title,charsmax(title),"%L",id,"AES_HOT_PLAYERS")
	
	// заголовок
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_META")
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_STYLE")
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_TOP_BODY",id,"AES_HOT_PLAYERS")
	
	// таблица со статистикой
	new row_str[512],cell_str[MAX_NAME_LENGTH * 3],row_len
	new desc_str[10],desc_char[4],bool:odd
	
	get_pcvar_string(cvar[CVAR_MOTD_DESC],desc_str,charsmax(desc_str))
	trim(desc_str)
	
	// TODO: AES RANKS
	replace(desc_str,charsmax(desc_str),"j","")
	
	new desc_length = strlen(desc_str)
	new skill_out = get_pcvar_num(cvar[CVAR_MOTD_SKILL_FMT])
	
	len += parse_top_desc_header(id,theBuffer,BUFF_LEN,len,false,desc_str)
	
	for(new i,stats[8],bh[8],player_id ,name[MAX_NAME_LENGTH] ; i < sizeof current_top ; i++)
	{
		player_id = current_top[i][0]
		
		if(!player_id)
		{
			continue
		}
		
		get_user_name(player_id,name,charsmax(name))
		
		#if !defined CSSTATSX_SQL
			get_user_stats(player_id,stats,bh)
		#else
			get_user_stats_sql(player_id,stats,bh)
		#endif
		
		for(new desc_index ; desc_index < desc_length ; desc_index++)
		{
			cell_str[0] = 0
			desc_char[0] = desc_str[desc_index]
			
			switch(desc_char[0]){
				// ранк
				case '*':
				{
					formatex(cell_str,charsmax(cell_str),"%d",current_top[i][1])
				}
				// ник
				case 'a':
				{
				
					formatex(cell_str,charsmax(cell_str),"%s",name)
					
					replace_all(cell_str,charsmax(cell_str),"<","&lt")
					replace_all(cell_str,charsmax(cell_str),">","&gt")
				}
				// убийства
				case 'b':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_KILLS])
				}
				// смерти
				case 'c':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_DEATHS])
				}
				// попадания
				case 'd':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_HITS])
				}
				// выстрелы
				case 'e':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_SHOTS])
				}
				// хедшоты
				case 'f':
				{
					formatex(cell_str,charsmax(cell_str),"%d",stats[STATS_HS])
				}
				// точнсть
				case 'g':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						accuracy(stats)
					)
				}
				// эффективность
				case 'h':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						effec(stats)
					)
				}
				
				// скилл
				case 'i':{
					new Float:skill ,skill_id
					
					#if defined CSSTATSX_SQL
						// используем скилл из csstatsx sql (ELO)
						get_user_skill(player_id,skill)
					#else
						// используем K:D для скилла
						skill = effec(stats)
					#endif
					
					skill_id =  aes_statsx_get_skill_id(skill)
					
					switch(skill_out)
					{
						// html
						case 0:
						{
							formatex(cell_str,charsmax(cell_str),"%L",
								id,
								"AES_SKILL_FMT",
								
								
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
					// TODO: AES RANKS
					formatex(cell_str,charsmax(cell_str),"lyl")
				}
				#endif
				// K:D
				case 'k':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f",
						kd_ratio(stats)
					)
				}
				// HS:K
				case 'l':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f",
						hsk_ratio(stats)
					)
				}
				// HS effec
				case 'm':
				{
					formatex(cell_str,charsmax(cell_str),"%.2f%%",
						effec_hs(stats)
					)
				}
				#if defined CSSTATSX_SQL
				// время в игре
				case 'n':
				{
					new ot = get_user_gametime(player_id)
					func_format_ot(ot,cell_str,charsmax(cell_str),id)
				}
				#endif
				default: continue
			}
			
			// выводим отформатированные данные
			row_len += formatex(row_str[row_len],charsmax(row_str)-row_len,"%L",id,"AES_BODY_CELL",cell_str)
		}
		
		row_len = len
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",id,"AES_BODY_ROW",odd ? " id=b" : " id=q",row_str)
		
		if(len >= BUFF_LEN)
		{
			theBuffer[row_len] = 0
		}
		
		row_len = 0
		odd ^= true
	}
	
	show_motd(id,theBuffer,title)
	
	return PLUGIN_HANDLED
}

public Sort_CurrentTop(const elem1[], const elem2[])
{
	if(elem1[1] < elem2[1])
	{
		return -1
	}
	else if(elem1[1] > elem2[1])
	{
		return 1
	}
	
	return 0
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
		if(strcmp(msg[1],"hot",1) == 0 || strcmp(msg[1],"topnow",1) == 0)
		{
			return ShowCurrentTop(id)
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
		#if defined CSSTATSX_SQL
		if(strcmp(msg[1],"sestats",1) == 0 || strcmp(msg[1],"history",1) == 0)
		{
			return SeStats_Show(id,id)
		}
		#endif
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
	
	if(rank > 0)
	{
		len += formatex(message[len],charsmax(message) - len,"%L ",id,"AES_YOUR_RANK_IS",rank,stats_num)
		len += parse_rank_desc(id,message[len],charsmax(message)-len,stats)
	}
	else
	{
		len += formatex(message[len],charsmax(message) - len,"%L ",id,"AES_STATS_INFO2")
	}
	
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
			#if defined CSSTATSX_SQL
			// время в игре
			case 'n':
			{
				new ot = get_user_gametime(id)
				
				len += formatex(msg[len],maxlen - len,"%L: ^3",id,"AES_TIME")
				len += func_format_ot(ot,msg[len],maxlen - len,id)
				len += formatex(msg[len],maxlen - len,"^1")
			}
			#endif
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

#if defined CSSTATSX_SQL
func_format_ot(ot,string[],len,idLang = LANG_SERVER)
{
	new d,h,m,s
	
	d = (ot / SECONDS_IN_DAY)
	ot -= (d * SECONDS_IN_DAY)
	h = (ot / SECONDS_IN_HOUR)
	ot -= (h * SECONDS_IN_HOUR)
	m = (ot / SECONDS_IN_MINUTE)
	ot -= (m * SECONDS_IN_MINUTE)
	s = ot
	
	if(d)
	{
		return formatex(string,len,"%L",idLang,"AES_STATS_DESC1",d,h,m)
	}
	else if(h)
	{
		return formatex(string,len,"%L",idLang,"AES_STATS_DESC2",h,m)
	}
	else if(m)
	{
		return formatex(string,len,"%L",idLang,"AES_STATS_DESC3",m)
	}
		
	return formatex(string,len,"%L",idLang,"AES_STATS_DESC4",s)
}
#endif
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
	
	if(!is_user_connected(player_id))
	{
		client_print_color(id,print_team_default,"%L %L",id,"STATS_TAG",id,"AES_STATS_INFO2")
		
		return PLUGIN_HANDLED
	}
	
	new len,motd_title[MAX_NAME_LENGTH]
	new name[MAX_NAME_LENGTH],rank,stats[8],bh[8],stats_num,Float:skill,skill_id,skill_str[64]
	
	#if defined CSSTATSX_SQL
		new stats3[STATS3_END]
		get_user_stats3_sql(player_id,stats3)
	#endif
	
	theBuffer[0] = 0
	
	formatex(motd_title,charsmax(motd_title),"%L",id,"RANKSTATS_TITLE")
	
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L",id,"AES_META")
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L",id,"AES_STYLE")
	
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
		formatex(name,charsmax(name),"%L",id,"AES_YOU")
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
				"AES_SKILL_FMT",
				
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
	
	new bool:is_wstats = false
	
	#if defined CSSTATSX_SQL
		is_wstats = (get_user_wstats_sql(player_id,0,stats,bh) == -1) ? false : true
	#endif
	
	//
	// Общая статистика
	//
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<td valign=top width=%d%% class=q><table cellspacing=0><tr><th colspan=2>",
		is_wstats ? 40 : 50
	)
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",
		id,"AES_RANKSTATS_TSTATS",
		name,rank,stats_num
	)
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%d (%L %d (%.2f%%))",id,"AES_KILLS",stats[STATS_KILLS],id,"AES_HS",stats[STATS_HS],effec_hs(stats))
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%d (%L %.2f)",id,"AES_DEATHS",stats[STATS_DEATHS],id,"AES_KS",kd_ratio(stats))
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%d",id,"AES_HITS",stats[STATS_HITS])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%d",id,"AES_SHOTS",stats[STATS_SHOTS])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%d",id,"AES_DMG",stats[STATS_DAMAGE])
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%.2f%%",id,"AES_ACC",accuracy(stats))
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%.2f%%",id,"AES_EFF",effec(stats))
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%s",id,"AES_SKILL",skill_str)
	
	#if !defined CSSTATSX_SQL
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td height=18px><td>")
	#else
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>",id,"AES_TIME")
		len += func_format_ot(
			get_user_gametime(player_id),
			theBuffer[len],charsmax(theBuffer)-len,
			id
		)
		
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%d",id,"CSXSQL_JOINS",stats3[STATS3_CONNECT])
		
		/*
		new from = get_systime() - get_user_lastjoin_sql(player_id)
		new from_str[40]
		get_time_length(id,from,timeunit_seconds,from_str,charsmax(from_str))
		
		len += formatex(theBuffer[len],charsmax(theBuffer)-len," (%L. %s %L)",
			id,"LAST",
			from_str,
			id,"AGO"
		)
		*/
		
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>%d (%L, %L)",id,"CSXSQL_ROUNDS",
			(stats3[STATS3_ROUNDT] + stats3[STATS3_ROUNDCT]),
			id,"CSXSQL_AS_T",stats3[STATS3_ROUNDT],
			id,"CSXSQL_AS_CT",stats3[STATS3_ROUNDCT]
		)
		
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=b><td>%L<td>%d (%L, %L)",id,"CSXSQL_WINS",
			(stats3[STATS3_WINT] + stats3[STATS3_WINCT]),
			id,"CSXSQL_AS_T",stats3[STATS3_WINT],
			id,"CSXSQL_AS_CT",stats3[STATS3_WINCT]
		)
		
		new firstjoin = get_user_firstjoin_sql(player_id)
		
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=q><td>%L<td>",id,"CSXSQL_FIRSTJOIN")
		
		if(firstjoin > 0)
		{
			len += format_time(theBuffer[len],charsmax(theBuffer)-len,"%m/%d/%Y - %H:%M:%S",firstjoin)
		}
		else
		{
			len += formatex(theBuffer[len],charsmax(theBuffer)-len,"-")
		}
	#endif
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"</td></tr></table></td>")
	
	#if !defined CSSTATSX_SQL
		//
		// Статистика по попаданиям
		//
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<td valign=top width=50%% class=q><table cellspacing=0><tr><th colspan=2>")
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",id,"AES_RANKSTATS_THITS")
			
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
	#else
		// статистика по оружию выключена
		if(!is_wstats)
		{
			//
			// Статистика по попаданиям
			//
			len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<td valign=top width=50%% class=q><table cellspacing=0><tr><th colspan=2>")
			len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",id,"AES_RANKSTATS_THITS")
				
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
			for(new i = 0 ; i < 5; ++i){
				len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<tr id=%s><td height=18px><td>",theSwitcher ? "b" : "q")
					
				theSwitcher = theSwitcher ? false : true
			}
			
			len += formatex(theBuffer[len],charsmax(theBuffer)-len,"</td>")
		}
		else
		{
			//
			// Статистика по используемому оружию
			//
			len += formatex(theBuffer[len],BUFF_LEN-len,"<td valign=top width=60%% class=q><table cellspacing=0 width=100%%><tr><th>%L<th>%L<th>%L<th>%L<th>%L<th>%L<th>%L",
				id,"AES_WEAPON",
				id,"AES_KILLS",
				id,"AES_DEATHS",
				id,"AES_HITS",
				id,"AES_SHOTS",
				id,"AES_DMG",
				id,"AES_ACC"
			)
				
			new bool:odd
			new wpn_stats[9],Array:wpn_stats_array = ArrayCreate(sizeof wpn_stats)
				
			for (new wpnId = 1,max_w = xmod_get_maxweapons_sql() ; wpnId < max_w ; wpnId++)
			{
				if (get_user_wstats_sql(player_id, wpnId, stats,bh))
				{
					wpn_stats[0] = stats[0]
					wpn_stats[1] = stats[1]
					wpn_stats[2] = stats[2]
					wpn_stats[3] = stats[3]
					wpn_stats[4] = stats[4]
					wpn_stats[5] = stats[5]
					wpn_stats[6] = stats[6]
					wpn_stats[7] = stats[7]
					wpn_stats[8] = wpnId
					
					ArrayPushArray(wpn_stats_array,wpn_stats)
				}
			}
			
			// сортируем по кол-ву убийств
			ArraySort(wpn_stats_array,"Sort_WeaponStats")
			
			for(new lena,i,wpnId,wpnName[MAX_NAME_LENGTH],length = ArraySize(wpn_stats_array) ; i < length && charsmax(theBuffer)-len > 0; i++)
			{
				ArrayGetArray(wpn_stats_array,i,wpn_stats)
				
				wpnId = wpn_stats[8]
				stats[0] = wpn_stats[0]
				stats[1] = wpn_stats[1]
				stats[2] = wpn_stats[2]
				stats[3] = wpn_stats[3]
				stats[4] = wpn_stats[4]
				stats[5] = wpn_stats[5]
				stats[6] = wpn_stats[6]
				stats[7] = wpn_stats[7]
				
				xmod_get_wpnname(wpnId,wpnName,charsmax(wpnName))
				
				lena = len
					
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
				
				// LENA FIX
				if(len >= BUFF_LEN)
				{
					len = lena
					theBuffer[len] = 0
					
					break
				}
						
				odd ^= true
			}
			
			ArrayDestroy(wpn_stats_array)
		}
	#endif
	
	show_motd(id,theBuffer,motd_title)
	
	return PLUGIN_HANDLED
}

#if defined CSSTATSX_SQL
	public Sort_WeaponStats(Array:array, item1, item2)
	{
		new wpn_stats1[9],wpn_stats2[9]
		ArrayGetArray(array,item1,wpn_stats1)
		ArrayGetArray(array,item2,wpn_stats2)
		
		if(wpn_stats1[0] > wpn_stats2[0])
		{
			return -1
		}
		else if(wpn_stats1[0] < wpn_stats2[0])
		{
			return 1
		}
		
		return 0
	}
#endif


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
	
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L%L",id,"AES_META",id,"AES_STYLE")
	len += formatex(theBuffer[len],BUFF_LEN-len,"%L",id,"AES_STATS_BODY")
	
	len += formatex(theBuffer[len],charsmax(theBuffer)-len,"<table cellspacing=10 cellpadding=0><tr>")
	
	len += formatex(theBuffer[len],BUFF_LEN-len,"<td valign=top width=20%% class=q><table cellspacing=0 width=100%%><tr><th colspan=2>%L<tr><td>%L<td>%d<tr class=b><td>%L<td>%d<tr><td>%L<td>%d<tr class=b><td>%L<td>%d<tr><td>%L<td>%d<tr class=b><td>%L<td>%d<tr><td>%L<td>%0.2f%%<tr class=b><td>%L<td>%0.2f%%</table>",
		id,"AES_STATS_HEADER1",
		id,"AES_KILLS",stats[STATS_KILLS],
		id,"AES_HS",stats[STATS_HS],
		id,"AES_DEATHS",stats[STATS_DEATHS],
		id,"AES_HITS",stats[STATS_HITS],
		id,"AES_SHOTS",stats[STATS_SHOTS],
		id,"AES_DMG",stats[STATS_DAMAGE],
		id,"AES_ACC",accuracy(stats),
		id,"AES_EFF",effec(stats))
		
	len += formatex(theBuffer[len],BUFF_LEN-len,"<td valign=top width=80%% class=q><table cellspacing=0 width=100%%><tr><th>%L<th>%L<th>%L<th>%L<th>%L<th>%L<th>%L",
		id,"AES_WEAPON",
		id,"AES_KILLS",
		id,"AES_DEATHS",
		id,"AES_HITS",
		id,"AES_SHOTS",
		id,"AES_DMG",
		id,"AES_ACC"
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
	
	#if defined CSSTATSX_SQL
	,STATSF_OT
	#endif
}

//
// Сбор статистики
//
public SayTopHandler(id,Pos)
{
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
			get_stats2_sql(i,stats2)
			get_stats_gametime(i,stats_info[STATSF_OT])
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
		
		if(!ArraySize(authids_array) || !aes_find_stats_thread(id,authids_array,"SayTopFormer",stats_data,sizeof stats_data))
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
	
	return (sizeof g_skill_opt - 1)
}

#if !defined AES
public SayTopFormer(id,stats_data[])
#else
public SayTopFormer(id,Array:aes_stats_array,stats_data[])
#endif
{
	theBuffer[0] = 0
	
	new Array:stats_array = Array:stats_data[0]
	
	new len,title[64]
	formatex(title,charsmax(title),"%L",id,"AES_PLAYER_TOP")
	
	// заголовок
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_META")
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_STYLE")
	len += formatex(theBuffer[len],BUFF_LEN - len,"%L",id,"AES_TOP_BODY",id,"AES_PLAYER_TOP")
	
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
								"AES_SKILL_FMT",
								
								
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
				#if defined CSSTATSX_SQL
				// время в игре
				case 'n':
				{
					new ot = stats_info[STATSF_OT]
					func_format_ot(ot,cell_str,charsmax(cell_str),id)
				}
				#endif
				default: continue
			}
			
			// выводим отформатированные данные
			row_len += formatex(row_str[row_len],charsmax(row_str)-row_len,"%L",id,"AES_BODY_CELL",cell_str)
		}
		
		row_len = 0
		
		len += formatex(theBuffer[len],charsmax(theBuffer)-len,"%L",id,"AES_BODY_ROW",odd ? " id=b" : " id=q",row_str)
		odd ^= true
	}
	
	ArrayDestroy(stats_array)
	
	#if defined AES
		ArrayDestroy(Array:stats_data[1])
		ArrayDestroy(aes_stats_array)
	#endif
	
	show_motd(id,theBuffer,title)
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
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_POS")
			}
			case 'a':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_PLAYER")
			}
			case 'b':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_KILLS")
			}
			case 'c':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_DEATHS")
			}
			case 'd':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_HITS")
			}
			case 'e':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_SHOTS")
			}
			case 'f':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_HS")
			}
			case 'g':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_ACC")
			}
			case 'h':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_EFF")
			}
			case 'i':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_SKILL")
			}
			#if !defined NO_AES
			case 'j':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_ARMYRANKS")
			}
			#endif
			case 'k':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_KS")
			}
			case 'l':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_HSK")
			}
			case 'm':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_HSP")
			}
			#if defined CSSTATSX_SQL
			case 'n':{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"AES_TIME")
			}
			case 'p':
			{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"CSXSQL_DATE")
			}
			case 'o':
			{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"CSXSQL_SKILLCHANGE")
			}
			case 'q':
			{
				len2 += formatex(tmp[len2],charsmax(tmp)-len2,"%L",id,"AES_HEADER_CELL","",id,"CSXSQL_MAP")
			}
			#endif
		}
		
		theChar[0] = 0
	}
	
	return formatex(buff[len],maxlen-len,"%L",id,"AES_TOP_HEADER_ROW",tmp)
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
	
	switch(g_MenuStatus[id][0])
	{
		case 0:menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n^n\r%d.\w %L",8,id,"MENU_RANK")
		case 1: menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n^n\r%d.\w %L",8,id,"MENU_STATS")
		#if defined CSSTATSX_SQL
		case 2: menuLen += formatex(menuText[menuLen],MENU_LEN - 1 - menuLen,"^n^n\r%d.\w %L",8,id,"CSXSQL_SETITLE")
		#endif
	
	}
	
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
			
			switch(g_MenuStatus[id][0])
			{
				case 0: RankStatsSay(id,usrIndex)
				case 1: StatsMeSay(id,usrIndex)
				#if defined CSSTATSX_SQL
				case 2: SeStats_Show(id,usrIndex)
				#endif
			}
			
			ShowStatsMenu(id,g_MenuStatus[id][1])
		}
		case 7:{
			g_MenuStatus[id][0] ++
			#if defined CSSTATSX_SQL
			if(g_MenuStatus[id][0] > 2)
				g_MenuStatus[id][0] = 0
			#else
			if(g_MenuStatus[id][0] > 1)
				g_MenuStatus[id][0] = 0
			#endif
			
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
