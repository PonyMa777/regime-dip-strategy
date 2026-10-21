function s = tradeStats(trades,equity,startEquity)
% One-row summary of closed trades and an equity path that starts from startEquity.
x=trades(trades.ExitReason~="OPEN",:); m=height(x);
[w,wlo,whi]=wilson(x.PnL>0);
mu=NaN; lo=NaN; hi=NaN;
if m>0, mu=mean(x.Return); end
if m>1, half=1.96*std(x.Return)/sqrt(m); lo=mu-half; hi=mu+half; end
peak=cummax([startEquity;equity(:)]); dd=equity(:)./peak(2:end)-1;
tot=NaN; mdd=NaN;
if ~isempty(equity), tot=equity(end)/startEquity-1; mdd=min([0;dd]); end
s=table(m,w,wlo,whi,mu,lo,hi,tot,mdd,mean(x.HoldDays),sum(x.ExitReason=="STOP"), ...
    'VariableNames',{'Trades','WinRate','WinLow95','WinHigh95','AvgReturn','AvgLow95','AvgHigh95', ...
    'TotalReturn','MaxDrawdown','AvgHoldDays','StopExits'});
end

function [p,lo,hi] = wilson(win)
% Win share with a Wilson 95% interval; NaN when empty.
m=numel(win); p=NaN; lo=NaN; hi=NaN;
if m==0, return; end
p=mean(win); z=1.96;
mid=(p+z^2/(2*m))/(1+z^2/m); half=z*sqrt(p*(1-p)/m+z^2/(4*m^2))/(1+z^2/m);
lo=mid-half; hi=mid+half;
end
