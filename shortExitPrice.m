function [reason,price] = shortExitPrice(o,h,l,entry,c)
% Mirror of chanExitPrice for a short: resting buy-to-cover orders from the short fill.
% Open gaps first; inside the bar the stop is assumed to fill before the target.
target=entry*(1-c.takeProfit); stop=entry*(1+c.stopLoss);
reason=""; price=NaN;
if o>=stop
    reason="STOP"; price=o*(1+c.slippageRate);
elseif o<=target
    reason="TAKE_PROFIT"; price=min(target,o*(1+c.slippageRate));
elseif h>=stop
    reason="STOP"; price=stop*(1+c.slippageRate);
elseif l<=target
    reason="TAKE_PROFIT"; price=target;
end
end
