function r = backtestRegimeDip(T,c,div,labels)
% Project 2: regime filter on Project 1's Chan signals (lib/). One position at a time.
% Signal confirmed at close t and filled at that close (plus slippage).
% BULL/RANGE: long on 1B/2B/3B. BEAR: long / none / short on 1S/2S/3S, per c.bearMode.
% Exits: take-profit/stop from the fill, intraday from the next bar on (gaps first, stop first).
% div: table ExDate, Amount. labels: optional signal override (used by the random-entry control).
required={'Date','Open','High','Low','Close'};
assert(all(ismember(required,T.Properties.VariableNames)), ...
    'Data requires Date, Open, High, Low, Close columns.');
assert(height(T)>0 && isdatetime(T.Date) && ~any(isnat(T.Date)) && issorted(T.Date) && ...
    numel(unique(T.Date))==height(T),'Dates must be valid, sorted and unique.');
v=T{:,{'Open','High','Low','Close'}};
assert(all(isfinite(v(:)) & v(:)>0) && all(T.High>=max(T.Open,T.Close)) && ...
    all(T.Low<=min(T.Open,T.Close)),'Invalid OHLC prices.');
assert(ismember(c.bearMode,{'long','none','short'}),'bearMode must be long, none or short.');
assert(c.initialCash>0 && c.cashFraction>0 && c.cashFraction<=1 && c.feeRate>=0 && ...
    c.slippageRate>=0 && c.slippageRate<1 && c.takeProfit>0 && c.takeProfit<1 && ...
    c.stopLoss>0 && c.stopLoss<1 && c.borrowRate>=0,'Invalid parameters.');
if nargin<3 || isempty(div), div=table(datetime.empty(0,1),zeros(0,1),'VariableNames',{'ExDate','Amount'}); end
n=height(T);
if nargin<4 || isempty(labels), labels=chanSignals(T,c).Label; end
regime=classifyRegime(T,c);
dps=zeros(n,1); [tf,loc]=ismember(div.ExDate,T.Date); dps(loc(tf))=div.Amount(tf);
buyTypes=["1B","2B","3B"]; buyTypes=buyTypes(logical(c.useBuy));
sellTypes=["1S","2S","3S"]; sellTypes=sellTypes(logical(c.useSell));
longOK=@(g) g=="BULL" || g=="RANGE" || (g=="NA" && c.tradeWithoutRegime) || ...
    (g=="BEAR" && strcmp(c.bearMode,'long'));
cash=c.initialCash; side=0; qty=0; ot=struct(); rows={};
equity=zeros(n,1); cashHistory=zeros(n,1); position=zeros(n,1);
for t=1:n
    exited=false;
    if side~=0
        % Carry for a position held overnight into today.
        d=qty*dps(t);
        if side>0 && c.creditLongDividends, cash=cash+d; ot.Dividends=ot.Dividends+d; end
        if side<0
            b=qty*ot.EntryPrice*c.borrowRate/252;
            cash=cash-d-b; ot.Dividends=ot.Dividends-d; ot.BorrowFee=ot.BorrowFee+b;
        end
        if side>0
            [reason,price]=chanExitPrice(T.Open(t),T.High(t),T.Low(t),ot.EntryPrice,c,false);
        else
            [reason,price]=shortExitPrice(T.Open(t),T.High(t),T.Low(t),ot.EntryPrice,c);
        end
        if reason~=""
            fee=qty*price*c.feeRate; cash=cash+side*qty*price-fee;
            ot.ExitReason=reason; ot.ExitDate=T.Date(t); ot.ExitPrice=price; ot.ExitFee=fee;
            ot.PnL=side*qty*(price-ot.EntryPrice)-ot.EntryFee-fee+ot.Dividends-ot.BorrowFee;
            ot.Return=ot.PnL/(qty*ot.EntryPrice+ot.EntryFee); ot.HoldDays=t-ot.Idx;
            rows{end+1}=rmfield(ot,'Idx'); side=0; qty=0; exited=true; %#ok<AGROW>
        end
    end
    if side==0 && ~exited
        g=regime(t); want=0;
        if longOK(g) && ismember(labels(t),buyTypes), want=1;
        elseif g=="BEAR" && strcmp(c.bearMode,'short') && ismember(labels(t),sellTypes), want=-1;
        end
        if want~=0
            price=T.Close(t)*(1+want*c.slippageRate);
            q=floor(cash*c.cashFraction/(price*(1+c.feeRate)));
            if q>0
                fee=q*price*c.feeRate; cash=cash-want*q*price-fee; side=want; qty=q;
                if want>0, name="LONG"; else, name="SHORT"; end
                ot=struct('Side',name, ...
                    'EntryType',labels(t),'Regime',g,'SignalDate',T.Date(t),'EntryDate',T.Date(t), ...
                    'EntryPrice',price,'Shares',q,'EntryFee',fee,'ExitReason',"OPEN",'ExitDate',NaT, ...
                    'ExitPrice',NaN,'ExitFee',NaN,'Dividends',0,'BorrowFee',0,'PnL',NaN,'Return',NaN, ...
                    'HoldDays',NaN,'Idx',t);
            end
        end
    end
    equity(t)=cash+side*qty*T.Close(t); cashHistory(t)=cash; position(t)=side*qty;
end
if side~=0
    ot.PnL=side*qty*(T.Close(n)-ot.EntryPrice)-ot.EntryFee+ot.Dividends-ot.BorrowFee; % marked, not closed
    ot.HoldDays=n-ot.Idx; rows{end+1}=rmfield(ot,'Idx');
end
if isempty(rows)
    r.Trades=table('Size',[0 17],'VariableTypes',{'string','string','string','datetime','datetime', ...
        'double','double','double','string','datetime','double','double','double','double','double', ...
        'double','double'},'VariableNames',{'Side','EntryType','Regime','SignalDate', ...
        'EntryDate','EntryPrice','Shares','EntryFee','ExitReason','ExitDate','ExitPrice','ExitFee', ...
        'Dividends','BorrowFee','PnL','Return','HoldDays'});
else
    r.Trades=struct2table([rows{:}],'AsArray',true);
end
% Buy-and-hold reference with the same entry costs; dividends excluded (price-only data).
bp=T.Open(1)*(1+c.slippageRate); bq=floor(c.initialCash/(bp*(1+c.feeRate)));
benchmark=c.initialCash-bq*bp*(1+c.feeRate)+bq*T.Close;
r.Daily=table(T.Date,T.Close,regime,labels,position,cashHistory,equity,benchmark, ...
    'VariableNames',{'Date','Close','Regime','Signal','Position','Cash','Equity','BuyHoldEquity'});
r.Summary=tradeStats(r.Trades,equity,c.initialCash);
r.Summary.BuyHoldReturn=benchmark(end)/c.initialCash-1;
end
