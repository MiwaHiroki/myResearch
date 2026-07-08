function togglevisibility(~,event)
    if strcmp(event.Peer.Visible,'on')
        event.Peer.Visible = 'off';
    else
        event.Peer.Visible = 'on';
    end
end
