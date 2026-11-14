function events = F_loadEvents(event_id)
% F_loadEvents  Load config/events.json (assumes cwd is the repo root).
%
% INPUT (optional):
%   event_id  string/char, e.g. '2003-10-29'. If given, returns just that
%             one event's struct. If omitted, returns the full struct array.
%
% OUTPUT:
%   events    struct array of all events, or a single event struct.

events = jsondecode(fileread('config/events.json'));

if nargin > 0 && ~isempty(event_id)
    ids = {events.id};
    idx = find(strcmp(ids, event_id));
    if isempty(idx)
        error("No event with id '%s' in config/events.json", event_id);
    end
    events = events(idx);
end

end
