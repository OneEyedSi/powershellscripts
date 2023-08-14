<#
.SYNOPSIS
Filters and reformats COVID-19 case numbers from Google.

.DESCRIPTION
To use the script copy and paste case number data from Google, at 
https://news.google.com/covid19/map?hl=en-NZ&gl=NZ&ceid=NZ:en, 
and assign it to $rawText before running the script.

To include a country in the output results add the country to the array $countriesToInclude.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.3.0 
Date:			9 Sep 2021

#>

# Capture the four numerical groups for total number of cases, new cases per day, 
# cases per million, and number died.  The numerical groups may include commas or be replaced by 
# "no data".  Exclude the 60-day trend chart text.
$regexPatternToFind = "^([\d|,|\w| |-]+)\t([\d|,|\w| |-]+)\t([\d|,|\w| |-]+)\t([\d|,|\w| |-]+)\t([\d|,|\w| |-]+)\t?"
# .NET regex substitutions are defined as "$<number>" rather than "\<number>".
$replacementPattern = '$1 / $2 / $4 / $5'

$countriesToInclude = @(
                        'Worldwide'
                        'United States'
                        'Spain'
                        'Italy'
                        'United Kingdom'
                        'Germany'
                        'France'
                        'Greece'
                        'Russia'
                        'Brazil'
                        'Iran'
                        'Iraq'
                        'Peru'
                        'Colombia'
                        'Turkey'
                        'China'
                        'Mexico'
                        'Canada'
                        'India'
                        'Pakistan'
                        'Bangladesh'
                        'Morocco'
                        'Switzerland'
                        'Portugal'
                        'Nepal'
                        'Hungary'
                        'Serbia'
                        'Austria'
                        'Ecuador'
                        'Sweden'
                        'Ireland'
                        'Chile'
                        'Saudi Arabia'
                        'Singapore'
                        'Israel'
                        'Japan'
                        'Indonesia'
                        'South Korea'
                        'South Africa'
                        'Denmark'
                        'Philippines'
                        'Norway'
                        'Australia'
                        'Malaysia'
                        'Finland'
                        'Argentina'
                        'Iceland'
                        'New Zealand'
                        'Hong Kong'
                        'Taiwan'
                        'Vietnam'
                        'French Polynesia'
                        'Fiji'
                        'New Caledonia'
                        'Papua New Guinea'
                        'Ukraine'
                        'Belgium'
                        'Netherlands'
                        'Czechia'
                        'Poland'
                        'Romania'
                        'Jordan'
                        'Panama'
                        'Georgia'
                        'Azerbaijan'
                        'Croatia'
                        'United Arab Emirates'
                        'Bulgaria'
                        'Kazakhstan'
                        )

$rawText = @"

Worldwide
219,456,675	No data	60-day trend chart	28,223	4,547,782

United States
40,567,387	184,007	60-day trend chart	123,097	653,216

India
33,096,718	37,875	60-day trend chart	24,326	441,411

Brazil
20,928,008	13,771	60-day trend chart	99,027	584,421

United Kingdom
7,094,592	38,486	60-day trend chart	106,789	133,674

Russia
6,964,595	17,673	60-day trend chart	47,460	186,224

France
6,702,711	0	60-day trend chart	99,927	113,385

Turkey
6,566,538	23,914	60-day trend chart	78,967	58,913

Argentina
5,215,332	3,531	60-day trend chart	116,054	112,962

Iran
5,210,978	26,854	60-day trend chart	62,533	112,430

Colombia
4,923,197	1,787	60-day trend chart	99,669	125,427

Spain
4,898,258	5,618	60-day trend chart	103,996	85,147

Italy
4,585,423	5,921	60-day trend chart	76,115	129,707

Indonesia
4,147,365	6,731	60-day trend chart	15,538	137,782

Germany
4,044,777	5,110	60-day trend chart	48,645	92,463

Mexico
3,465,171	15,876	60-day trend chart	27,376	265,420

Poland
2,891,602	531	60-day trend chart	75,343	75,403

South Africa
2,836,773	6,939	60-day trend chart	48,265	84,152

Ukraine
2,404,585	3,123	60-day trend chart	57,416	57,472

Peru
2,157,536	1,085	60-day trend chart	67,147	198,595

Philippines
2,134,005	12,697	60-day trend chart	19,671	34,672

Netherlands
1,961,585	2,781	60-day trend chart	112,405	18,055

Iraq
1,934,335	5,405	60-day trend chart	49,436	21,282

Malaysia
1,900,467	19,733	60-day trend chart	58,051	19,163

Czechia
1,681,681	590	60-day trend chart	157,256	30,408

Chile
1,642,146	355	60-day trend chart	85,944	37,122

Japan
1,606,710	12,411	60-day trend chart	12,757	16,561

Canada
1,529,801	3,307	60-day trend chart	40,280	27,106

Bangladesh
1,522,302	2,497	60-day trend chart	9,041	26,736

Thailand
1,322,519	14,176	60-day trend chart	19,891	13,511

Belgium
1,201,056	2,553	60-day trend chart	104,218	25,442

Pakistan
1,194,198	4,062	60-day trend chart	5,449	26,497

Israel
1,139,887	22,291	60-day trend chart	124,171	7,261

Sweden
1,135,160	1,711	60-day trend chart	109,853	14,700

Romania
1,111,155	2,079	60-day trend chart	57,261	34,792

Portugal
1,050,719	1,778	60-day trend chart	102,244	17,826

Kazakhstan
900,172	4,408	60-day trend chart	48,203	14,423

Morocco
893,462	3,930	60-day trend chart	24,918	13,296

Hungary
814,064	246	60-day trend chart	83,299	30,077

Jordan
804,326	975	60-day trend chart	75,528	10,501

Switzerland
802,048	3,551	60-day trend chart	93,407	10,940

Serbia
794,528	5,633	60-day trend chart	114,095	7,445

Nepal
773,529	1,347	60-day trend chart	25,787	10,889

United Arab Emirates
726,025	833	60-day trend chart	73,407	2,053

Cuba
712,992	8,317	60-day trend chart	63,605	5,967

Austria
701,216	2,268	60-day trend chart	78,765	10,815

Tunisia
680,074	4,303	60-day trend chart	58,017	24,041

Lebanon
610,197	1,008	60-day trend chart	89,400	8,144

Greece
607,356	2,198	60-day trend chart	56,632	14,014

Georgia
570,493	2,571	60-day trend chart	153,216	7,977

Vietnam
563,676	12,680	60-day trend chart	5,859	14,135

Saudi Arabia
545,505	0	60-day trend chart	15,942	8,591

Ecuador
504,257	374	60-day trend chart	28,886	32,365

Guatemala
497,690	5,120	60-day trend chart	29,974	12,468

Belarus
495,578	1,760	60-day trend chart	52,646	3,871

Bolivia
493,518	403	60-day trend chart	43,027	18,529

Costa Rica
483,984	2,884	60-day trend chart	95,687	5,702

Sri Lanka
474,780	2,917	60-day trend chart	21,776	10,689

Bulgaria
466,671	1,956	60-day trend chart	66,667	19,335

Panama
460,829	330	60-day trend chart	109,232	7,104

Paraguay
459,062	85	60-day trend chart	64,180	16,020

Azerbaijan
447,725	0	60-day trend chart	44,474	5,920

Myanmar (Burma)
423,104	2,702	60-day trend chart	7,786	16,173

Kuwait
410,562	66	60-day trend chart	92,885	2,427

Slovakia
396,904	417	60-day trend chart	72,742	12,553

Uruguay
386,082	156	60-day trend chart	109,728	6,037

Croatia
379,963	1,237	60-day trend chart	93,214	8,395

Ireland
360,957	1,537	60-day trend chart	73,343	5,155

Dominican Republic
352,201	192	60-day trend chart	34,002	4,013

Denmark
350,405	514	60-day trend chart	60,178	2,599

Honduras
348,894	1,383	60-day trend chart	38,096	9,224

Venezuela
342,148	0	60-day trend chart	10,619	4,133

Palestine
335,709	No data	60-day trend chart	67,456	3,669

Libya
319,568	1,499	60-day trend chart	46,508	4,374

Ethiopia
319,101	1,529	60-day trend chart	3,234	4,830

Lithuania
304,600	908	60-day trend chart	109,040	4,630

Oman
302,867	52	60-day trend chart	64,926	4,083

Egypt
291,172	399	60-day trend chart	2,906	16,824

Bahrain
273,366	114	60-day trend chart	177,131	1,388

Slovenia
272,512	1,094	60-day trend chart	130,136	4,461

Moldova
272,325	790	60-day trend chart	101,548	6,466

South Korea
267,470	2,047	60-day trend chart	5,165	2,343

Armenia
246,410	645	60-day trend chart	83,317	4,954

Mongolia
243,719	3,677	60-day trend chart	73,618	982

Kenya
241,783	649	60-day trend chart	5,083	4,830

Qatar
234,093	165	60-day trend chart	85,209	604

Bosnia and Herzegovina
219,010	930	60-day trend chart	66,347	9,951

Zambia
207,442	148	60-day trend chart	11,598	3,622

Algeria
198,962	317	60-day trend chart	4,627	5,489

Nigeria
197,046	559	60-day trend chart	956	2,578

North Macedonia
181,620	701	60-day trend chart	87,438	6,153

Kyrgyzstan
176,779	97	60-day trend chart	27,057	2,561

Norway
171,719	1,546	60-day trend chart	31,992	826

Botswana
162,186	0	60-day trend chart	69,344	2,309

Uzbekistan
161,768	660	60-day trend chart	4,743	1,132

Kosovo
154,607	1,029	60-day trend chart	86,100	2,709

Afghanistan
153,736	110	60-day trend chart	4,771	7,151

Albania
153,318	1,079	60-day trend chart	53,872	2,528

Mozambique
148,552	108	60-day trend chart	4,941	1,888

Latvia
145,402	459	60-day trend chart	76,254	2,595

Estonia
144,878	488	60-day trend chart	109,065	1,305

Finland
131,686	632	60-day trend chart	23,823	1,039

Zimbabwe
125,931	135	60-day trend chart	8,307	4,517

Namibia
125,897	125	60-day trend chart	51,200	3,417

Ghana
122,543	386	60-day trend chart	4,047	1,084

Uganda
120,847	133	60-day trend chart	2,999	3,068

Montenegro
119,602	533	60-day trend chart	192,175	1,780

Cyprus
115,657	182	60-day trend chart	132,044	523

Cambodia
96,935	596	60-day trend chart	6,340	1,987

El Salvador
96,067	0	60-day trend chart	14,811	2,986

Mainland China
95,083	No data	60-day trend chart	68	4,636

Rwanda
91,081	483	60-day trend chart	7,360	1,147

Cameroon
84,210	0	60-day trend chart	3,172	1,357

Maldives
82,364	100	60-day trend chart	219,769	227

Luxembourg
76,455	97	60-day trend chart	124,541	833

Jamaica
73,496	672	60-day trend chart	26,955	1,666

Senegal
73,310	53	60-day trend chart	4,523	1,816

Singapore
69,582	349	60-day trend chart	12,200	56

Australia
66,318	No data	60-day trend chart	2,584	1,053

Malawi
60,965	67	60-day trend chart	3,187	2,229

Côte d'Ivoire
57,293	134	60-day trend chart	2,219	488

Democratic Republic of the Congo
54,009	No data	60-day trend chart	603	1,053

Réunion
51,651	1,305	60-day trend chart	60,062	354

Guadeloupe
49,515	4,044	60-day trend chart	125,133	606

Angola
49,349	235	60-day trend chart	1,585	1,309

Fiji
48,393	240	60-day trend chart	54,688	528

Trinidad and Tobago
46,283	270	60-day trend chart	33,932	1,348

Eswatini
44,500	121	60-day trend chart	40,705	1,163

Madagascar
42,884	0	60-day trend chart	1,634	957

French Polynesia
40,178	0	60-day trend chart	145,616	535

Martinique
38,786	170	60-day trend chart	103,023	527

Sudan
37,877	2	60-day trend chart	893	2,837

Malta
36,606	53	60-day trend chart	74,167	446

French Guiana
36,221	186	60-day trend chart	123,171	224

Cape Verde
36,202	116	60-day trend chart	65,764	317

Mauritania
34,504	96	60-day trend chart	8,462	743

Suriname
31,894	502	60-day trend chart	54,860	746

Guinea
29,918	41	60-day trend chart	2,449	360

Syria
28,952	138	60-day trend chart	1,654	2,055

Guyana
26,772	0	60-day trend chart	34,202	654

Gabon
26,379	202	60-day trend chart	12,142	169

Togo
23,018	186	60-day trend chart	3,054	203

Haiti
21,124	30	60-day trend chart	1,825	588

Seychelles
20,281	0	60-day trend chart	207,744	103

Mayotte
19,947	22	60-day trend chart	73,776	175

Benin
19,106	2,160	60-day trend chart	1,628	141

The Bahamas
19,035	0	60-day trend chart	49,398	453

Timor-Leste
18,046	158	60-day trend chart	13,009	86

Papua New Guinea
18,012	0	60-day trend chart	2,016	192

Somalia
17,947	0	60-day trend chart	1,129	1,005

Tajikistan
17,424	19	60-day trend chart	1,909	125

Belize
17,251	132	60-day trend chart	42,231	369

Laos
16,576	211	60-day trend chart	2,327	16

Taiwan
16,056	9	60-day trend chart	680	837

Curaçao
15,550	44	60-day trend chart	98,005	151

Andorra
15,070	0	60-day trend chart	194,344	130

Mali
14,961	12	60-day trend chart	749	542

Aruba
14,955	42	60-day trend chart	133,159	153

Lesotho
14,395	0	60-day trend chart	7,172	403

Burkina Faso
13,872	4	60-day trend chart	665	171

Republic of the Congo
13,533	No data	60-day trend chart	2,452	183

Mauritius
12,616	0	60-day trend chart	9,965	34

Burundi
12,585	0	60-day trend chart	1,149	38

Nicaragua
12,350	0	60-day trend chart	1,912	201

Hong Kong
12,131	2	60-day trend chart	1,617	212

Djibouti
11,807	15	60-day trend chart	10,949	157

South Sudan
11,571	37	60-day trend chart	906	120

Central African Republic
11,296	0	60-day trend chart	2,055	100

Iceland
11,130	40	60-day trend chart	30,555	33

Equatorial Guinea
9,939	0	60-day trend chart	7,317	129

The Gambia
9,789	0	60-day trend chart	4,170	328

Saint Lucia
9,327	69	60-day trend chart	52,195	128

Jersey
9,249	No data	60-day trend chart	86,601	77

Yemen
8,230	49	60-day trend chart	276	1,541
Northern Cyprus
7,720	No data	60-day trend chart	23,681	34

Isle of Man
6,923	40	60-day trend chart	83,095	38

Eritrea
6,651	0	60-day trend chart	1,902	40

Sierra Leone
6,376	0	60-day trend chart	807	121

Guinea-Bissau
5,943	9	60-day trend chart	3,704	122

Niger
5,896	4	60-day trend chart	264	199

Liberia
5,727	0	60-day trend chart	1,280	245

Barbados
5,573	87	60-day trend chart	19,416	51

Gibraltar
5,402	3	60-day trend chart	160,292	97

San Marino
5,358	7	60-day trend chart	159,588	90

Chad
5,011	15	60-day trend chart	308	174

Comoros
4,093	3	60-day trend chart	4,685	147

Sint Maarten
3,921	33	60-day trend chart	96,543	57

New Zealand
3,847	18	60-day trend chart	773	27

Brunei
3,683	116	60-day trend chart	8,325	16

Saint Martin
3,544	181	60-day trend chart	99,144	31

Liechtenstein
3,352	9	60-day trend chart	86,505	59

Bermuda
3,273	0	60-day trend chart	51,119	35

Monaco
3,260	7	60-day trend chart	85,117	33

Turks and Caicos Islands
2,727	11	60-day trend chart	65,919	20

São Tomé and Príncipe
2,709	12	60-day trend chart	13,425	38

British Virgin Islands
2,642	2	60-day trend chart	87,979	37

Bhutan
2,596	0	60-day trend chart	3,500	3

Saint Vincent and the Grenadines
2,389	4	60-day trend chart	21,599	12

Dominica
2,175	177	60-day trend chart	30,289	6

Antigua and Barbuda
1,974	14	60-day trend chart	20,466	47

Caribbean Netherlands
1,885	22	60-day trend chart	72,536	17

Grenada
1,748	135	60-day trend chart	15,607	14

Saint Barthélemy
1,607	14	60-day trend chart	No data	2

Guernsey
1,384	No data	60-day trend chart	No data	16

Tanzania
1,367	0	60-day trend chart	24	50

Saint Kitts and Nevis
1,310	31	60-day trend chart	24,800	5

Faroe Islands
1,022	0	60-day trend chart	19,607	2

Cayman Islands
719	4	60-day trend chart	10,925	2

Åland Islands
455	No data	60-day trend chart	15,225	No data

Greenland
377	17	60-day trend chart	6,722	0

Anguilla
305	9	60-day trend chart	20,512	0

New Caledonia
152	9	60-day trend chart	539	0

Falkland Islands (Islas Malvinas)
67	0	60-day trend chart	No data	0

Macao
63	0	60-day trend chart	93	0

Montserrat
31	0	60-day trend chart	No data	1

Saint Pierre and Miquelon
31	0	60-day trend chart	No data	0

Vatican City
27	0	60-day trend chart	No data	0

Western Sahara
10	No data	60-day trend chart	17	1
*The number of new cases reported for the most recent day of complete d
"@

Clear-Host

$regex = New-Object System.Text.RegularExpressions.Regex `
		-ArgumentList @($regexPatternToFind, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

$resultArray = @('Case numbers: Total / New Cases Per Day / Cases per 1 million people / Died')
$countryArray = $rawText -Split [Environment]::NewLine + [Environment]::NewLine
foreach ($countryData in $countryArray)
{    
    $countryParts = $countryData -Split [Environment]::NewLine

    $country = $countryParts[0]

    # To deal with leading blank line, if copied data sloppily.
    $i = 1
    while (-not $country -and $i -lt $countryParts.Count)
    {
        $country = $countryParts[$i]
        $i++
    }

    # This will be false if $country not set.
    if ($countriesToInclude -contains $country)
    {
        $numText = $regex.Replace($countryParts[$i], $replacementPattern)
        $resultArray += "${country}: $numText"
    }
}

$resultArray | Format-Table

Write-Host