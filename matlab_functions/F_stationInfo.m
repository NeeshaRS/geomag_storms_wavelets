function T = F_stationInfo()
% F_stationInfo  Static lookup of station code -> full site name / location,
% for the three networks used in this repo (CARISMA, IMAGE, DTU/Greenland).
% Transcribed 2026-08-26 from the networks' own station listings:
%   CARISMA: https://www.carisma.ca/station-information
%   IMAGE:   https://space.fmi.fi/image/www/index.php?page=stations
%   DTU:     https://www.space.dtu.dk/english/research/scientific_data_and_models/magnetic-ground-stations
%
% IMAGE's station page does not give a country/region per station, so
% 'location' is left blank ("") for IMAGE-only codes rather than guessed --
% fill those in by hand if/when needed. DTU's page groups stations under
% explicit region headers (e.g. "Greenland (West Coast)"), so those are
% used as-is. Where a code is listed by both IMAGE and DTU (e.g. NAQ, SCO),
% the DTU entry wins, matching Data_processing.m's rule that DTU (the
% station operator) takes priority over a redistributing feed. OTT is not
% on any of the three pages; added from common knowledge (Natural
% Resources Canada's Ottawa magnetic observatory).
%
% OUTPUT:
%   T  table with columns: site, name, location (all string). Not
%      exhaustive -- Map_Events.m falls back to the site code itself for
%      any station not listed here.

carisma = {
    "ANNA", "Ann Arbor",        "Michigan, USA"
    "BACK", "Back Lake",        "Canada"
    "CONT", "Contwoyto",        "Canada"
    "DAWS", "Dawson City",      "Yukon, Canada"
    "ESKI", "Eskimo Point",     "Canada"
    "FCHP", "Fort Chipewyan",   "Alberta, Canada"
    "FCHU", "Fort Churchill",   "Manitoba, Canada"
    "FSIM", "Fort Simpson",     "Northwest Territories, Canada"
    "FSMI", "Fort Smith",       "Northwest Territories, Canada"
    "GILL", "Gillam",           "Manitoba, Canada"
    "GULL", "Gull Lake",        "Canada"
    "ISLL", "Island Lake",      "Canada"
    "LGRR", "Little Grand Rapids", "Canada"
    "MCMU", "Fort McMurray",    "Alberta, Canada"
    "MSTK", "Ministik Lake",    "Alberta, Canada"
    "NORM", "Norman Wells",     "Northwest Territories, Canada"
    "OSAK", "Osakis",           "Minnesota, USA"
    "OXFO", "Oxford House",     "Canada"
    "PINA", "Pinawa",           "Manitoba, Canada"
    "POLS", "Polson",           "Montana, USA"
    "RABB", "Rabbit Lake",      "Canada"
    "RANK", "Rankin Inlet",     "Nunavut, Canada"
    "SACH", "Sachs Harbour",    "Canada"
    "TALO", "Taloyoak",         "Canada"
    "THRF", "Thief River Falls", "Minnesota, USA"
    "VULC", "Vulcan",           "Alberta, Canada"
    "WEYB", "Weyburn",          "Saskatchewan, Canada"
    "WGRY", "Wells Gray",       "British Columbia, Canada"
};

image = {
    "NRD", "Nord",              ""
    "NAL", "Ny Ålesund",        ""
    "LYR", "Longyearbyen",      ""
    "HOR", "Hornsund",          ""
    "HOP", "Hopen Island",      ""
    "BJN", "Bear Island",       ""
    "NOR", "Nordkapp",          ""
    "JAN", "Jan Mayen",         ""
    "SOR", "Sørøya",            ""
    "SCO", "Ittoqqortoormiit",  ""
    "ALT", "Alta",              ""
    "KEV", "Kevo",              ""
    "TRO", "Tromsø",            ""
    "MAS", "Masi",              ""
    "AND", "Andenes",           ""
    "KIL", "Kilpisjärvi",       ""
    "KAU", "Kautokeino",        ""
    "IVA", "Ivalo",             ""
    "ABK", "Abisko",            ""
    "LEK", "Leknes",            ""
    "MUO", "Muonio",            ""
    "LOZ", "Lovozero",          ""
    "KIR", "Kiruna",            ""
    "RST", "Røst",              ""
    "SOD", "Sodankylä",         ""
    "PEL", "Pello",             ""
    "JCK", "Jäckvik",           ""
    "DON", "Dønna",             ""
    "RAN", "Ranua",             ""
    "KUL", "Kulusuk",           ""
    "RVK", "Rørvik",            ""
    "LYC", "Lycksele",          ""
    "OUJ", "Oulujärvi",         ""
    "LRV", "Leirvogur",         ""
    "MEK", "Mekrijärvi",        ""
    "HAN", "Hankasalmi",        ""
    "HAS", "Hassela",           ""
    "DOB", "Dombås",            ""
    "HOV", "Hov",               ""
    "NAQ", "Narsarsuaq",        ""
    "SOL", "Solund",            ""
    "NUR", "Nurmijärvi",        ""
    "HAR", "Harestua",          ""
    "AAL", "Åland",             ""
    "UPS", "Uppsala",           ""
    "NRA", "Nora",              ""
    "KAR", "Karmøy",            ""
    "TAR", "Tartu",             ""
    "FKP", "Falköping",         ""
    "GOT", "Gotland",           ""
    "SIN", "Sindal",            ""
    "VXJ", "Växjö",             ""
    "BRZ", "Birzai",            ""
    "BOR", "Bornholm",          ""
    "ROE", "Rømø",              ""
    "HLP", "Hel",               ""
    "SUW", "Suwałki",           ""
    "WNG", "Wingst",            ""
    "NGK", "Niemegk",           ""
    "PPN", "Polesie",           ""
};

dtu = {
    "THL", "Qaanaaq (Thule)",              "Greenland (West Coast)"
    "TAB", "Thule Air Base",               "Greenland (West Coast)"
    "SVS", "Savissivik",                   "Greenland (West Coast)"
    "KUV", "Kullorsuaq",                   "Greenland (West Coast)"
    "UPN", "Upernavik",                    "Greenland (West Coast)"
    "UMQ", "Uummannaq (Umanaq)",           "Greenland (West Coast)"
    "GDH", "Qeqertarsuaq (Godhavn)",       "Greenland (West Coast)"
    "ATU", "Attu",                         "Greenland (West Coast)"
    "STF", "Kangerlussuaq (Sondre Stromfjord)", "Greenland (West Coast)"
    "SKT", "Maniitsoq (Sukkertoppen)",     "Greenland (West Coast)"
    "GHB", "Nuuk (Godthaab)",              "Greenland (West Coast)"
    "FHB", "Paamiut (Frederikshaab)",      "Greenland (West Coast)"
    "NAQ", "Narsarsuaq",                   "Greenland (West Coast)"
    "NRD", "Nord",                         "Greenland (East Coast)"
    "DMH", "Danmarkshavn",                 "Greenland (East Coast)"
    "DNB", "Daneborg",                     "Greenland (East Coast)"
    "SCO", "Ittoqqortoormiit (Scorebysund)", "Greenland (East Coast)"
    "AMK", "Tasiilaq (Ammassalik)",        "Greenland (East Coast)"
    "SUM", "Summit",                       "Greenland (Ice Cap)"
    "HOV", "Hov",                          "Faroe Islands"
    "BFE", "Brorfelde",                    "Denmark"
    "ROE", "Rømø",                         "Denmark"
    "TDC", "Tristan da Cunha",             "South Atlantic"
};

other = {
    "OTT", "Ottawa",                       "Ontario, Canada"
};

% DTU overrides IMAGE for shared codes (DTU is the station operator; see
% Data_processing.m's Greenland-merge note), so build in this order and
% let later rows win on duplicate site codes.
rows = [carisma; image; dtu; other];

site     = string(rows(:,1));
name     = string(rows(:,2));
location = string(rows(:,3));

[site_u, ia] = unique(site, 'last');
T = table(site_u, name(ia), location(ia), 'VariableNames', {'site','name','location'});

end
