function [G,R] = runGrid(nRandom)
% Pre-registered grid: stop {1..5}% x bearMode {long (= P1), none (v1a), short (v1b)},
% reported for in-sample 1993-2015 and out-of-sample 2016-end. All rows are reported.
% R: random-entry control for v1b (same label counts placed on random days).
if nargin==0, nRandom=200; end
root=fileparts(mfilename('fullpath')); out=fullfile(root,'results'); if ~isfolder(out), mkdir(out); end
[T,div]=loadData();
periods={'IS',datetime(1993,1,1),datetime(2015,12,31); 'OOS',datetime(2016,1,1),T.Date(end)};
modes={'long','none','short'}; groups={'P1','v1a','v1b'}; stops=0.01:0.01:0.05;
G=table(); R=table(); rng(20261021);
base=regimeConfig(); labels=chanSignals(T,base).Label;
for sl=stops
    for m=1:3
        c=base; c.stopLoss=sl; c.bearMode=modes{m};
        r=backtestRegimeDip(T,c,div,labels);
        for p=1:2
            G=[G;periodRow(r,T,periods(p,:),groups{m},sl,c)]; %#ok<AGROW>
        end
    end
    % Random-entry control for v1b: shuffle signal days, keep how many of each label.
    c=base; c.stopLoss=sl; c.bearMode='short';
    idx=find(labels~=""); valid=(c.maLen+c.slopeDays):height(T);
    mu=nan(nRandom,2);
    for k=1:nRandom
        L=strings(height(T),1); L(valid(randperm(numel(valid),numel(idx))))=labels(idx);
        q=backtestRegimeDip(T,c,div,L);
        for p=1:2, s=periodRow(q,T,periods(p,:),'rand',sl,c); mu(k,p)=s.AvgReturn; end
    end
    for p=1:2
        actual=G.AvgReturn(G.Group=="v1b" & G.StopPct==100*sl & G.Period==periods{p,1});
        R=[R;table(100*sl,string(periods{p,1}),actual,mean(mu(:,p),'omitnan'), ...
            prctile(mu(:,p),95),mean(mu(:,p)>=actual), ...
            'VariableNames',{'StopPct','Period','V1bAvgReturn','RandomMeanAvg','Random95th','ShareRandomAtLeastAsGood'})]; %#ok<AGROW>
    end
end
% Success check (README): OOS max drawdown at least 20% smaller than P1, and AvgLow95 >= 0.
G.DDvsP1=nan(height(G),1); G.Success=false(height(G),1);
for i=1:height(G)
    b=G.Group=="P1" & G.StopPct==G.StopPct(i) & G.Period==G.Period(i);
    G.DDvsP1(i)=G.MaxDrawdown(i)/G.MaxDrawdown(b);
    G.Success(i)=G.Period(i)=="OOS" && G.Group(i)~="P1" && G.DDvsP1(i)<=0.8 && G.AvgLow95(i)>=0;
end
writetable(G,fullfile(out,'grid.csv')); writetable(R,fullfile(out,'random_control.csv'));
disp(G(:,{'Period','Group','StopPct','Trades','Longs','Shorts','WinRate','AvgReturn','AvgLow95', ...
    'TotalReturn','MaxDrawdown','DDvsP1','Success'})); disp(R);
fprintf('Results: %s\n',out);
end

function s = periodRow(r,T,per,group,sl,c)
% Trades whose signal falls in the period; equity re-based at the period start.
in=T.Date>=per{2} & T.Date<=per{3}; i0=find(in,1);
tr=r.Trades(r.Trades.SignalDate>=per{2} & r.Trades.SignalDate<=per{3},:);
start=c.initialCash; if i0>1, start=r.Daily.Equity(i0-1); end
s=tradeStats(tr,r.Daily.Equity(in),start);
s.Longs=sum(tr.Side=="LONG" & tr.ExitReason~="OPEN"); s.Shorts=sum(tr.Side=="SHORT" & tr.ExitReason~="OPEN");
s=[table(string(per{1}),string(group),100*sl,'VariableNames',{'Period','Group','StopPct'}),s];
end
