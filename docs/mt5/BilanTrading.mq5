//+------------------------------------------------------------------+
//| BilanTrading.mq5                                                 |
//| Envoie automatiquement vos trades fermes vers Bilan trading.     |
//| Le robot ne passe aucun ordre : il lit seulement l'historique.   |
//+------------------------------------------------------------------+
#property copyright "Bilan trading"
#property version   "1.00"
#property description "Envoie vos trades fermes vers votre journal Bilan trading."
#property description "Collez votre cle (Reglages > Connexion MetaTrader 5) dans Cle."

input string Cle             = "";   // Cle de connexion (Reglages > Connexion MetaTrader 5)
input int    JoursHistorique = 30;   // Premier lancement : jours d'historique a envoyer

string API_URL = "https://adbaxplykdvghxfgtsiu.supabase.co/rest/v1/rpc/mt5_trade";
string API_KEY = "sb_publishable_5ZstOMK8k4CvrBdswDSwoA_9c2Av71O";

string   g_cle    = "";
string   g_var    = "";
bool     g_alerte = false;
int      g_envoyes = 0;
datetime g_dernier = 0;
string   g_etat   = "demarrage";

//+------------------------------------------------------------------+
string Echap(string s)
  {
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return s;
  }

string Nombre(double v, int digits)
  {
   if(!MathIsValidNumber(v)) return "null";
   string s = DoubleToString(v, digits);
   return s;
  }

// Remplace {e} {E} {a} {c} {o} par les lettres accentuees (le fichier reste en ASCII)
string Fr(string s)
  {
   StringReplace(s, "{e}", ShortToString(0x00E9));
   StringReplace(s, "{E}", ShortToString(0x00C9));
   StringReplace(s, "{a}", ShortToString(0x00E0));
   StringReplace(s, "{c}", ShortToString(0x00E7));
   StringReplace(s, "{o}", ShortToString(0x00F4));
   return s;
  }

string Deux(int v) { return (v < 10 ? "0" : "") + IntegerToString(v); }

string NomActif(string sym)
  {
   int p = StringFind(sym, ".");
   if(p > 0) sym = StringSubstr(sym, 0, p);
   p = StringFind(sym, "#");
   if(p > 0) sym = StringSubstr(sym, 0, p);
   return sym;
  }

void Statut()
  {
   string t = "Bilan trading : " + g_etat;
   if(g_envoyes > 0) t += "\n" + IntegerToString(g_envoyes) + Fr(" trade(s) envoy{e}(s) depuis le lancement");
   if(g_dernier > 0) t += Fr("\nDernier trade envoy{e} : ") + TimeToString(g_dernier, TIME_DATE | TIME_MINUTES);
   Comment(t);
  }

//+------------------------------------------------------------------+
//| Envoi d'un trade. Retour : 1 = ok, 0 = a reessayer, -1 = abandon |
//+------------------------------------------------------------------+
int Envoyer(string json)
  {
   char data[], res[];
   string rh;
   int n = StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(n > 0) ArrayResize(data, n - 1);
   string headers = "Content-Type: application/json\r\napikey: " + API_KEY + "\r\n";
   ResetLastError();
   int code = WebRequest("POST", API_URL, headers, 8000, data, res, rh);
   if(code == -1)
     {
      int err = GetLastError();
      if(err == 4014)
        {
         g_etat = Fr("adresse non autoris{e}e. Outils > Options > Expert Advisors : autorisez le WebRequest pour https://adbaxplykdvghxfgtsiu.supabase.co");
         if(!g_alerte) { Alert("Bilan trading : ", g_etat); g_alerte = true; }
        }
      else g_etat = "pas de connexion (erreur " + IntegerToString(err) + "), nouvel essai dans une minute";
      return 0;
     }
   string body = CharArrayToString(res, 0, WHOLE_ARRAY, CP_UTF8);
   if(code >= 200 && code < 300) return 1;
   if(StringFind(body, "inconnue") >= 0)
     {
      g_etat = Fr("cl{e} inconnue. Copiez la cl{e} depuis R{e}glages > Connexion MetaTrader 5.");
      if(!g_alerte) { Alert("Bilan trading : ", g_etat); g_alerte = true; }
      return 0;
     }
   if(StringFind(body, "bloqu") >= 0) { g_etat = Fr("compte bloqu{e} par l'administrateur."); return 0; }
   if(code >= 500 || code == 429) { g_etat = Fr("serveur occup{e}, nouvel essai dans une minute"); return 0; }
   Print("Bilan trading : trade ignore (", code, ") ", body);
   return -1;
  }

//+------------------------------------------------------------------+
//| Construit le trade a partir du deal de sortie                    |
//+------------------------------------------------------------------+
string Construire(ulong sortie)
  {
   if(!HistoryDealSelect(sortie)) return "";
   long     pos    = HistoryDealGetInteger(sortie, DEAL_POSITION_ID);
   string   sym    = HistoryDealGetString(sortie, DEAL_SYMBOL);
   long     typ    = HistoryDealGetInteger(sortie, DEAL_TYPE);
   datetime quand  = (datetime)HistoryDealGetInteger(sortie, DEAL_TIME);
   double   vol    = HistoryDealGetDouble(sortie, DEAL_VOLUME);
   double   prixS  = HistoryDealGetDouble(sortie, DEAL_PRICE);
   double   profit = HistoryDealGetDouble(sortie, DEAL_PROFIT);
   double   swap   = HistoryDealGetDouble(sortie, DEAL_SWAP);
   double   comm   = HistoryDealGetDouble(sortie, DEAL_COMMISSION);
   double   fee    = HistoryDealGetDouble(sortie, DEAL_FEE);
   double   slS    = HistoryDealGetDouble(sortie, DEAL_SL);
   double   tpS    = HistoryDealGetDouble(sortie, DEAL_TP);
   int      digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0) digits = 5;
   // Une sortie par une vente ferme un achat (long), et inversement.
   bool long_ = (typ == DEAL_TYPE_SELL);

   double volE = 0, valE = 0, commE = 0, sl = 0, tp = 0;
   if(HistorySelectByPosition(pos))
     {
      int nd = HistoryDealsTotal();
      for(int i = 0; i < nd; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         long e = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(e == DEAL_ENTRY_IN || e == DEAL_ENTRY_INOUT)
           {
            double v = HistoryDealGetDouble(d, DEAL_VOLUME);
            volE  += v;
            valE  += v * HistoryDealGetDouble(d, DEAL_PRICE);
            commE += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
            if(sl == 0) sl = HistoryDealGetDouble(d, DEAL_SL);
            if(tp == 0) tp = HistoryDealGetDouble(d, DEAL_TP);
           }
        }
     }
   double prixE = volE > 0 ? valE / volE : 0;
   if(sl == 0) sl = slS;
   if(tp == 0) tp = tpS;
   // Commission d'entree au prorata de la partie fermee
   double commPart = (volE > 0 ? commE * MathMin(1.0, vol / volE) : 0);
   double resultat = profit + swap + comm + fee + commPart;
   double frais    = -(comm + fee + commPart);

   // Stop valable seulement s'il est du cote perdant
   bool stopOk = (prixE > 0 && sl > 0 && ((long_ && sl < prixE) || (!long_ && sl > prixE)));
   double risque = 0;
   if(stopOk)
     {
      double p = 0;
      if(OrderCalcProfit(long_ ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, sym, vol, prixE, sl, p)) risque = MathAbs(p);
     }

   // Heure locale de l'ordinateur (l'heure du serveur du courtier est souvent differente)
   long decal = (long)(TimeLocal() - TimeTradeServer());
   decal = (long)MathRound(decal / 900.0) * 900;
   datetime loc = (datetime)((long)quand + decal);
   MqlDateTime t; TimeToStruct(loc, t);
   string date  = IntegerToString(t.year) + "-" + Deux(t.mon) + "-" + Deux(t.day);
   string heure = Deux(t.hour) + ":" + Deux(t.min);

   string j = "{\"p_cle\":\"" + Echap(g_cle) + "\",\"p_t\":{";
   j += "\"ticket\":\"" + IntegerToString((long)sortie) + "\"";
   j += ",\"date\":\"" + date + "\",\"heure\":\"" + heure + "\"";
   j += ",\"actif\":\"" + Echap(NomActif(sym)) + "\"";
   j += ",\"sens\":\"" + (long_ ? "long" : "short") + "\"";
   if(prixE > 0) j += ",\"entree\":" + Nombre(prixE, digits);
   j += ",\"sortie\":" + Nombre(prixS, digits);
   j += ",\"lots\":" + Nombre(vol, 2);
   j += ",\"frais\":" + Nombre(frais, 2);
   if(stopOk) j += ",\"stop\":" + Nombre(sl, digits);
   if(tp > 0) j += ",\"tp\":" + Nombre(tp, digits);
   if(risque > 0) j += ",\"risque\":" + Nombre(risque, 2);
   j += ",\"resultat\":" + Nombre(resultat, 2);
   j += "}}";
   return j;
  }

//+------------------------------------------------------------------+
//| Cherche les trades fermes depuis le dernier envoi                |
//+------------------------------------------------------------------+
void Synchroniser()
  {
   if(StringLen(g_cle) < 32) { g_etat = Fr("collez votre cl{e} dans Cle (clic droit sur le graphique > Liste des experts > Propri{e}t{e}s)"); Statut(); return; }
   datetime depuis = (datetime)(GlobalVariableCheck(g_var) ? (long)GlobalVariableGet(g_var) : (long)(TimeTradeServer() - (long)MathMax(1, JoursHistorique) * 86400));
   if(!HistorySelect(depuis, TimeTradeServer() + 86400)) { g_etat = "historique indisponible"; Statut(); return; }

   ulong    tickets[];
   datetime heures[];
   int total = HistoryDealsTotal(), k = 0;
   ArrayResize(tickets, total);
   ArrayResize(heures, total);
   for(int i = 0; i < total; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      long e = HistoryDealGetInteger(d, DEAL_ENTRY);
      long ty = HistoryDealGetInteger(d, DEAL_TYPE);
      if((e == DEAL_ENTRY_OUT || e == DEAL_ENTRY_OUT_BY || e == DEAL_ENTRY_INOUT) && (ty == DEAL_TYPE_BUY || ty == DEAL_TYPE_SELL))
        {
         datetime h = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         if(h < depuis) continue;
         tickets[k] = d; heures[k] = h; k++;
        }
     }
   // du plus ancien au plus recent
   for(int a = 1; a < k; a++)
     {
      ulong tk = tickets[a]; datetime hh = heures[a]; int b = a - 1;
      while(b >= 0 && heures[b] > hh) { tickets[b + 1] = tickets[b]; heures[b + 1] = heures[b]; b--; }
      tickets[b + 1] = tk; heures[b + 1] = hh;
     }

   int faits = 0;
   for(int i = 0; i < k && faits < 50; i++)
     {
      string json = Construire(tickets[i]);
      int r = (json == "" ? -1 : Envoyer(json));
      if(r == 0) { Statut(); return; }          // on reessaiera a partir de ce trade
      if(r == 1) { g_envoyes++; g_dernier = heures[i]; }
      faits++;
      GlobalVariableSet(g_var, (double)((long)heures[i] + 1));
     }
   if(k == 0 && !GlobalVariableCheck(g_var)) GlobalVariableSet(g_var, (double)(long)depuis);
   g_etat = Fr("connect{e}. Les trades ferm{e}s arrivent dans l'appli.");
   g_alerte = false;
   Statut();
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_cle = Cle;
   StringTrimLeft(g_cle); StringTrimRight(g_cle);
   g_var = "BilanT_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + StringSubstr(g_cle, 0, 8);
   EventSetTimer(60);
   Synchroniser();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
  }

void OnTimer()
  {
   EventKillTimer();
   Synchroniser();
   EventSetTimer(60);
  }

void OnTick() { }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) { EventKillTimer(); EventSetTimer(5); }   // envoi rapide apres une cloture
  }
//+------------------------------------------------------------------+
