function testRegimeDip()
% Project 2 tests: regime labels, short exits, short accounting, mode rules, causality,
% and (when Project 1 is next to this folder) equivalence with Project 1 when the filter is off.
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'lib'));
c=regimeConfig();

% Regime: rising series is BULL after warm-up, falling is BEAR, NA before MA and slope exist.
t=(1:400)'; up=table(datetime(2000,1,3)+caldays(t-1),100+0.1*t,'VariableNames',{'Date','Close'});
g=classifyRegime(up,c); w=c.maLen+c.slopeDays;
assert(all(g(1:w-1)=="NA") && all(g(w:end)=="BULL"));
dn=up; dn.Close=200-0.1*t; g=classifyRegime(dn,c); assert(all(g(w:end)=="BEAR"));

% Short exits mirror the long rules (zero slippage for exact prices).
c0=c; c0.slippageRate=0; c0.takeProfit=0.015; c0.stopLoss=0.05;
[why,p]=shortExitPrice(100,100.5,98.5,100,c0); assert(why=="TAKE_PROFIT" && abs(p-98.5)<1e-10);
[why,p]=shortExitPrice(100,105,99,100,c0); assert(why=="STOP" && abs(p-105)<1e-10);
[why,p]=shortExitPrice(100,105,98,100,c0); assert(why=="STOP" && abs(p-105)<1e-10); % both touched: stop first
[why,p]=shortExitPrice(107,108,106,100,c0); assert(why=="STOP" && p==107);          % gap up through stop
[why,p]=shortExitPrice(97,99,96,100,c0); assert(why=="TAKE_PROFIT" && p==97);        % gap down through target
[why,~]=shortExitPrice(100,104.9,98.6,100,c0); assert(why=="");

% Synthetic market: up, down, up, with waves that create Chan signals.
t=(1:1500)'; trend=[linspace(0,60,500)';linspace(60,-10,500)';linspace(-10,50,500)'];
px=100+trend+6*sin(2*pi*t/37).*(1+0.5*sin(2*pi*t/200))+2.5*sin(2*pi*t/11);
o=[px(1);px(1:end-1)];
T=table(datetime(2000,1,3)+caldays(t-1),o,max(o,px)+0.3,min(o,px)-0.3,px, ...
    'VariableNames',{'Date','Open','High','Low','Close'});
div=table(T.Date(50:5:end),0.05*ones(numel(50:5:1500),1),'VariableNames',{'ExDate','Amount'}); % dense, so holds span ex-dates

% Mode rules.
r=backtestRegimeDip(T,c,div); tr=r.Trades;
assert(any(tr.Side=="SHORT") && any(tr.Side=="LONG"),'Fixture must trade both sides.');
assert(all(tr.Regime(tr.Side=="SHORT")=="BEAR") && all(ismember(tr.EntryType(tr.Side=="SHORT"),["1S","2S","3S"])));
assert(all(ismember(tr.Regime(tr.Side=="LONG"),["BULL","RANGE"])) && all(ismember(tr.EntryType(tr.Side=="LONG"),["1B","2B","3B"])));
cn=c; cn.bearMode='none'; q=backtestRegimeDip(T,cn,div);
assert(~any(q.Trades.Regime=="BEAR") && all(q.Trades.Side=="LONG"));
assert(all(tr.EntryDate==tr.SignalDate));
s=tr(tr.Side=="SHORT",:); [~,i]=ismember(s.SignalDate,T.Date);
assert(max(abs(s.EntryPrice-T.Close(i)*(1-c.slippageRate)))<1e-10); % short fill at close minus slippage
assert(all(tr.HoldDays(tr.ExitReason~="OPEN")>=1));                  % no exit on the entry bar

% Accounting: final equity = initial + all trade PnL (open trade marked to the last close).
assert(abs(r.Daily.Equity(end)-(c.initialCash+sum(tr.PnL)))<1e-6);
% Short carry: borrow fee = rate * days / 252 * notional; dividends paid on ex-dates held through.
for k=find(tr.Side=="SHORT" & tr.ExitReason~="OPEN")'
    assert(abs(tr.BorrowFee(k)-c.borrowRate*tr.HoldDays(k)/252*tr.Shares(k)*tr.EntryPrice(k))<1e-8);
    held=div.ExDate>tr.EntryDate(k) & div.ExDate<=tr.ExitDate(k);
    assert(abs(tr.Dividends(k)+tr.Shares(k)*sum(div.Amount(held)))<1e-8);
end
assert(any(tr.Dividends<0),'Fixture should hold a short through an ex-date.');

% Causality: changing prices after day m leaves earlier trades unchanged.
m=1100; U=T; f=1.2; U{m+1:end,{'Open','High','Low','Close'}}=U{m+1:end,{'Open','High','Low','Close'}}*f;
q=backtestRegimeDip(U,c,div);
a=tr(tr.ExitReason~="OPEN" & tr.ExitDate<=T.Date(m),:); b=q.Trades(q.Trades.ExitReason~="OPEN" & q.Trades.ExitDate<=T.Date(m),:);
assert(isequal(a,b) && isequal(r.Daily.Regime(1:m),q.Daily.Regime(1:m)));

% Missing Low is rejected.
rejected=false; try, backtestRegimeDip(removevars(T,'Low'),c,div); catch, rejected=true; end
assert(rejected);

% Equivalence with Project 1 when the filter is off (needs ../decline_flat_rebound/已审查).
p1=fullfile(fileparts(root),'decline_flat_rebound','已审查');
if isfolder(p1) && isfile(fullfile(p1,'backtestChan.m'))
    addpath(p1);
    for X={T, loadData()}
        U=X{1}; ce=c; ce.bearMode='long'; ce.tradeWithoutRegime=true; ce.creditLongDividends=false;
        mine=backtestRegimeDip(U,ce,[]); theirs=backtestChan(U,ce);
        cols={'EntryType','SignalDate','EntryDate','EntryPrice','Shares','EntryFee','ExitReason', ...
            'ExitDate','ExitPrice','ExitFee','HoldDays'};
        A=mine.Trades(mine.Trades.ExitReason~="OPEN",:); B=theirs.Trades(theirs.Trades.ExitReason~="OPEN",:);
        assert(isequal(A(:,cols),B(:,cols)),'bearMode=long without the filter must reproduce Project 1 trades.');
        assert(max(abs(A.PnL-B.PnL))<1e-6 && max(abs(A.Return-B.Return))<1e-12); % same sums, different order
        assert(max(abs(mine.Daily.Equity-theirs.Daily.Equity))<1e-6);
    end
    fprintf('Project 1 equivalence: PASS (synthetic and SPY).\n');
else
    fprintf('Project 1 equivalence: SKIPPED (Project 1 folder not found next to this repo).\n');
end
fprintf('PASS: Project 2 regime, short exits, carry, modes, accounting, causality.\n');
end
