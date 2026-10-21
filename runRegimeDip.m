function r = runRegimeDip(c)
% One backtest on data/SPY_1993_2026.csv with regimeConfig() (or a config you pass), plus a chart.
if nargin==0, c=regimeConfig(); end
root=fileparts(mfilename('fullpath'));
[T,div]=loadData(); r=backtestRegimeDip(T,c,div);
out=fullfile(root,'results',sprintf('single_%s_stop%g',c.bearMode,100*c.stopLoss));
if ~isfolder(out), mkdir(out); end
writetable(r.Daily,fullfile(out,'daily.csv'));
writetable(r.Trades,fullfile(out,'trades.csv'));
writetable(r.Summary,fullfile(out,'summary.csv'));
label=sprintf('Project 2 | bear=%s | TP %.1f%% SL %.1f%%',c.bearMode,100*c.takeProfit,100*c.stopLoss);
f=figure('Name',label,'Color','w','Position',[100 100 1100 800],'Visible','off'); tiledlayout(3,1);
nexttile; hold on;
colors=containers.Map({'BULL','RANGE','BEAR','NA'},{[0.85 0.95 0.85],[0.95 0.95 0.95],[0.98 0.85 0.85],[1 1 1]});
yl=[min(T.Close)*0.9 max(T.Close)*1.05];
g=r.Daily.Regime; k=1;
while k<=height(T)
    e=k; while e<height(T) && g(e+1)==g(k), e=e+1; end
    fill(T.Date([k e e k]),yl([1 1 2 2]),colors(char(g(k))),'EdgeColor','none');
    k=e+1;
end
plot(T.Date,T.Close,'k','LineWidth',0.8);
tr=r.Trades; L=tr.Side=="LONG"; S=tr.Side=="SHORT";
h1=scatter(tr.EntryDate(L),tr.EntryPrice(L),25,[0 0.55 0],'^','filled');
h2=scatter(tr.EntryDate(S),tr.EntryPrice(S),25,[0.85 0 0],'v','filled');
legend([h1 h2],{'Long entry','Short entry'},'Location','northwest');
ylim(yl); title([label ' | green = BULL, grey = RANGE, red = BEAR']); ylabel('SPY'); grid on;
nexttile; plot(T.Date,[r.Daily.Equity,r.Daily.BuyHoldEquity],'LineWidth',1.1);
legend('Strategy','Buy and hold (price only)','Location','northwest'); ylabel('Account value'); grid on;
nexttile; peak=cummax(r.Daily.Equity); plot(T.Date,100*(r.Daily.Equity./peak-1),'LineWidth',1.1);
ylabel('Drawdown (%)'); grid on;
% Force a light chart even when MATLAB uses a dark theme.
for a=findall(f,'Type','axes')'
    a.Color='w'; a.XColor='k'; a.YColor='k'; a.GridColor=[0.15 0.15 0.15];
    a.Title.Color='k'; a.XLabel.Color='k'; a.YLabel.Color='k';
end
for lg=findall(f,'Type','legend')', lg.Color='w'; lg.TextColor='k'; lg.EdgeColor=[0.6 0.6 0.6]; end
exportgraphics(f,fullfile(out,'backtest.png')); close(f);
disp(label); disp(r.Summary); fprintf('Results: %s\n',out);
end
