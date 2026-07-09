$ErrorActionPreference = "Stop"
$OutputDocPath = "C:\Users\LENOVO\Desktop\cleancity2.1\docs\rapport\Rapport_PFE_CleanCity.docx"

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Add()
$sel = $word.Selection

function Get-Sty($name) {
    try { return $doc.Styles.Item($name) } catch { return $null }
}
function Set-Sty($primary, $fallback) {
    $s = Get-Sty $primary
    if (-not $s) { $s = Get-Sty $fallback }
    if ($s) { $sel.Style = $s }
}

# ---------- Page setup ----------
$doc.PageSetup.PageWidth = $word.CentimetersToPoints(21)
$doc.PageSetup.PageHeight = $word.CentimetersToPoints(29.7)
$doc.PageSetup.TopMargin = $word.CentimetersToPoints(2.5)
$doc.PageSetup.BottomMargin = $word.CentimetersToPoints(2.5)
$doc.PageSetup.LeftMargin = $word.CentimetersToPoints(3)
$doc.PageSetup.RightMargin = $word.CentimetersToPoints(2)

$normal = Get-Sty "Normal"
$normal.Font.Name = "Calibri"
$normal.Font.Size = 11
$normal.ParagraphFormat.Alignment = 3
$normal.ParagraphFormat.LineSpacingRule = 1
$normal.ParagraphFormat.SpaceAfter = 8

foreach ($hname in @("Heading 1","Titre 1")) {
    $h = Get-Sty $hname
    if ($h) { $h.Font.Name = "Calibri"; $h.Font.Size = 16; $h.Font.Bold = 1; $h.Font.Color = 1783296; $h.ParagraphFormat.SpaceBefore = 6; $h.ParagraphFormat.SpaceAfter = 12; break }
}
foreach ($hname in @("Heading 2","Titre 2")) {
    $h = Get-Sty $hname
    if ($h) { $h.Font.Name = "Calibri"; $h.Font.Size = 13.5; $h.Font.Bold = 1; $h.Font.Color = 1783296; $h.ParagraphFormat.SpaceBefore = 10; break }
}
foreach ($hname in @("Heading 3","Titre 3")) {
    $h = Get-Sty $hname
    if ($h) { $h.Font.Name = "Calibri"; $h.Font.Size = 12; $h.Font.Bold = 1; $h.Font.Italic = 0; $h.Font.Color = 0; break }
}

$footer = $doc.Sections.Item(1).Footers.Item(1)
$footer.PageNumbers.Add(1) | Out-Null

# ---------- Helper functions ----------
function P { param([string]$text)
    Set-Sty "Normal" "Normal"
    $sel.Font.Bold = 0; $sel.Font.Italic = 0; $sel.Font.Size = 11; $sel.Font.Color = 0
    $sel.ParagraphFormat.Alignment = 3
    $sel.TypeText($text)
    $sel.TypeParagraph()
}
function H1 { param([string]$text)
    Set-Sty "Heading 1" "Titre 1"
    $sel.TypeText($text)
    $sel.TypeParagraph()
    Set-Sty "Normal" "Normal"
}
function H2 { param([string]$text)
    Set-Sty "Heading 2" "Titre 2"
    $sel.TypeText($text)
    $sel.TypeParagraph()
    Set-Sty "Normal" "Normal"
}
function H3 { param([string]$text)
    Set-Sty "Heading 3" "Titre 3"
    $sel.TypeText($text)
    $sel.TypeParagraph()
    Set-Sty "Normal" "Normal"
}
function CenterLine { param([string]$text, [double]$size = 12, [int]$bold = 0, [int]$italic = 0)
    $sel.ParagraphFormat.Alignment = 1
    $sel.Font.Size = $size
    $sel.Font.Bold = $bold
    $sel.Font.Italic = $italic
    $sel.TypeText($text)
    $sel.TypeParagraph()
    $sel.Font.Bold = 0; $sel.Font.Italic = 0; $sel.Font.Size = 11
    $sel.ParagraphFormat.Alignment = 3
}
function PlaceholderLine { param([string]$text, [double]$size = 12)
    $sel.ParagraphFormat.Alignment = 1
    $sel.Font.Size = $size
    $sel.Font.Bold = 1
    $sel.Font.Color = 255
    $sel.TypeText($text)
    $sel.TypeParagraph()
    $sel.Font.Bold = 0; $sel.Font.Color = 0; $sel.Font.Size = 11
    $sel.ParagraphFormat.Alignment = 3
}
function PageBreak { $sel.InsertBreak(7) | Out-Null }
function Blank { $sel.TypeParagraph() }

function Bullet { param([string]$text)
    Set-Sty "List Bullet" "Liste à puces"
    $sel.TypeText($text)
    $sel.TypeParagraph()
    Set-Sty "Normal" "Normal"
}

function Caption { param([string]$text)
    $sel.ParagraphFormat.Alignment = 1
    $sel.Font.Bold = 1
    $sel.Font.Italic = 1
    $sel.Font.Size = 10
    $sel.TypeText($text)
    $sel.TypeParagraph()
    $sel.Font.Bold = 0; $sel.Font.Italic = 0; $sel.Font.Size = 11
    $sel.ParagraphFormat.Alignment = 3
}

function Tbl { param([string[]]$headers, [System.Object[]]$rows)
    $sel.TypeParagraph()
    $r = $sel.Range
    $nRows = $rows.Count + 1
    $nCols = $headers.Count
    $tbl = $doc.Tables.Add($r, $nRows, $nCols)
    $tbl.Borders.Enable = 1
    $tbl.AutoFitBehavior(2)
    for ($c = 1; $c -le $nCols; $c++) {
        $cell = $tbl.Cell(1, $c)
        $cell.Range.Text = $headers[$c - 1]
        $cell.Range.Font.Bold = 1
        $cell.Range.Font.Size = 10
        $cell.Shading.BackgroundPatternColor = 14277081
    }
    for ($ri = 0; $ri -lt $rows.Count; $ri++) {
        $row = $rows[$ri]
        for ($c = 1; $c -le $nCols; $c++) {
            $cell = $tbl.Cell($ri + 2, $c)
            $cell.Range.Text = [string]$row[$c - 1]
            $cell.Range.Font.Size = 10
        }
    }
    $sel.EndKey(6) | Out-Null
    $sel.TypeParagraph()
}

function Callout { param([string]$label, [string]$desc)
    $sel.ParagraphFormat.Shading.Texture = 1
    $sel.ParagraphFormat.Shading.BackgroundPatternColor = 15987699
    $sel.ParagraphFormat.Alignment = 0
    $sel.Font.Bold = 1
    $sel.Font.Size = 10.5
    $sel.TypeText("Emplacement visuel suggere -- " + $label)
    $sel.TypeParagraph()
    $sel.Font.Bold = 0
    $sel.Font.Italic = 1
    $sel.TypeText($desc)
    $sel.TypeParagraph()
    $sel.Font.Italic = 0
    $sel.Font.Size = 11
    $sel.ParagraphFormat.Alignment = 3
    $sel.ParagraphFormat.Shading.Texture = 0
}

# ============================================================================
# PAGE DE GARDE
# ============================================================================
Blank
PlaceholderLine "[NOM DE L'UNIVERSITE / INSTITUT SUPERIEUR]" 14
PlaceholderLine "[Faculte / Ecole - Departement d'Informatique et Génie Logiciel]" 12
Blank
CenterLine "MÉMOIRE DE FIN D'ÉTUDES" 13 1
CenterLine "En vue de l'obtention de la Licence en Informatique / Génie Logiciel" 12 0 1
Blank
Blank
CenterLine "CLEANCITY" 30 1
CenterLine "Une plateforme mobile et web pour la gestion participative" 14 1
CenterLine "des déchets urbains au Cameroun" 14 1
Blank
CenterLine "« Collect . Recover . Preserve »" 12 0 1
Blank
Blank
CenterLine "Présente par :" 11 0
PlaceholderLine "[Prenom NOM de l'étudiant(e)]" 13
Blank
CenterLine "Sous l'encadrement de :" 11 0
PlaceholderLine "[Titre et Nom de l'encadreur académique]" 12
Blank
Blank
PlaceholderLine "Année académique [2025 - 2026]" 12
PlaceholderLine "Soutenu le [date de soutenance]" 11
Blank
PageBreak

# ============================================================================
# DEDICACE
# ============================================================================
H1 "Dedicace"
P "[Section a personnaliser par l'étudiant.]"
Blank
CenterLine "A ma famille, pour son soutien constant tout au long de ce parcours académique," 12 0 1
CenterLine "A mes enseignants, pour la rigueur et les connaissances transmises," 12 0 1
CenterLine "A mes camarades de promotion, pour leur solidarite," 12 0 1
CenterLine "Je dedie ce travail." 12 0 1
PageBreak

# ============================================================================
# REMERCIEMENTS
# ============================================================================
H1 "Remerciements"
P "Au terme de la rédaction de ce mémoire, je tiens a exprimer ma sincere gratitude a l'ensemble des personnes qui ont contribue, de pres ou de loin, a la réalisation de ce projet de fin d'études."
P "Mes remerciements s'adressent en premier lieu a [Nom de l'encadreur académique], pour son encadrement rigoureux, sa disponibilite et ses conseils avises qui ont guide chaque étape de ce travail, de la conception a la rédaction finale."
P "Je remercie également l'ensemble du corps professoral et administratif de [Nom de l'universite / institut], dont l'enseignement m'a permis d'acquerir les fondements théoriques et pratiques nécessaires a la conduite de ce projet."
P "Mes remerciements vont aussi aux membres du jury, qui me font l'honneur d'évaluer ce travail, ainsi qu'a toute personne ayant accepte de participer aux échanges et tests informels autour de l'application CleanCity."
P "Enfin, une pensee particulière pour ma famille et mes proches, pour leur soutien moral et leur patience durant toute la duree de ce projet."
PageBreak

# ============================================================================
# RÉSUMÉ / ABSTRACT
# ============================================================================
H1 "Résumé"
P "Les villes camerounaises font face a une pression croissante liée a la gestion des déchets solides urbains, conséquence directe d'une urbanisation rapide et d'une insuffisance des dispositifs numériques de suivi de la salubrite publique. Le signalement d'un point de décharge sauvage, la coordination des équipes de collecte et le suivi du traitement des déchets reposent encore largement sur des circuits informels, peu traçables et difficilement mesurables par les autorites municipales."
P "Le present mémoire documenté la conception, le développement et le déploiement de CleanCity, une application mobile et web multiplateforme permettant de mettre en relation trois catégories d'acteurs -- les citoyens générateurs de déchets, les collecteurs et les centres de tri -- autour d'un cycle complet de signalement, de géolocalisation, de collecte et de valorisation des déchets, supervise par un espace d'administration. L'application s'appuie sur une architecture client-serveur moderne : un client Flutter multiplateforme (Android, iOS, Web) communique avec Supabase, une plateforme Backend-as-a-Service fondee sur PostgreSQL et l'extension géospatiale PostGIS, qui assure l'authentification, le stockage des données, le stockage de fichiers et la sécurité d'accès via des politiques Row Level Security (RLS)."
P "Le rapport détaillé successivement le contexte et la problématique locale, le cahier des charges fonctionnel et technique, l'analyse et la conception du système (architecture, modèle de données, diagrammes UML), la réalisation technique, la stratégie de tests, ainsi que le processus de déploiement continu via GitHub Actions. Il se conclut par un bilan critique du projet et des perspectives d'évolution, notamment l'amelioration du fonctionnement hors connexion et l'intégration de moyens de paiement mobiles réels, deux enjeux particulièrement pertinents dans le contexte camerounais."
P "Mots-clés : gestion des déchets, salubrite urbaine, Cameroun, Supabase, Backend-as-a-Service, PostGIS, géolocalisation, application mobile Flutter, Row Level Security, développement durable."
PageBreak

H1 "Abstract"
P "Cameroonian cities face growing pressure related to urban solid waste management, a direct conséquence of rapid urbanization combined with a lack of digital tools for tracking public sanitation in real time. Reporting an illegal dumping site, coordinating collection teams, and monitoring waste treatment still largely rely on informal, poorly traceable channels that are difficult for municipal authorities to measure and act upon."
P "This report documents the design, development, and deployment of CleanCity, a cross-platform mobile and web application connecting three catégories of stakeholders -- waste-generating citizens, collectors, and sorting/processing centers -- around a complete cycle of reporting, geolocation, collection, and waste recovery, supervised through an administration space. The application relies on a modern client-server architecture: a cross-platform Flutter client (Android, iOS, Web) communicates with Supabase, a Backend-as-a-Service platform built on PostgreSQL and the PostGIS géospatial extension, which handles authentication, data storage, file storage, and access security through Row Level Security (RLS) policies."
P "The report successively details the local context and problem statement, the functional and technical requirements, the system analysis and design (architecture, data model, UML diagrams), the technical implémentation, the testing strategy, and the continuous deployment process via GitHub Actions. It concludes with a critical assessment of the project and perspectives for future development, in particular improved offline functionality and intégration of real mobile-money payment channels, two issues that are especially relevant in the Cameroonian context."
P "Keywords: waste management, urban sanitation, Cameroon, Supabase, Backend-as-a-Service, PostGIS, geolocation, Flutter mobile application, Row Level Security, sustainable development."
PageBreak

# ============================================================================
# LISTE DES ABREVIATIONS
# ============================================================================
H1 "Liste des abreviations et acronymes"
Tbl @("Sigle","Signification") @(
    @("API","Application Programming Interface (interface de programmation applicative)"),
    @("BaaS","Backend-as-a-Service"),
    @("CI/CD","Continuous Intégration / Continuous Deployment (intégration et déploiement continus)"),
    @("CRUD","Create, Read, Update, Delete"),
    @("GPS","Global Positioning System"),
    @("JWT","JSON Web Token"),
    @("MINEPDED","Ministere de l'Environnement, de la Protection de la Nature et du Développement Durable (Cameroun)"),
    @("OTP","One-Time Password"),
    @("PostGIS","Extension géospatiale du système de gestion de base de données PostgreSQL"),
    @("REST","Representational State Transfer"),
    @("RLS","Row Level Security (sécurité au niveau des lignes)"),
    @("RPC","Remote Procédure Call"),
    @("SDK","Software Development Kit"),
    @("SGBD","Système de Gestion de Base de Données"),
    @("SQL","Structured Query Language"),
    @("UML","Unified Modeling Language"),
    @("UI/UX","User Interface / User Experience"),
    @("UUID","Universally Unique Identifier"),
    @("XAF","Franc CFA (BEAC), devise utilisée en Afrique centrale")
)
PageBreak

# ============================================================================
# LISTE DES FIGURES ET TABLEAUX (statique)
# ============================================================================
H1 "Liste des figures"
Bullet "Figure 1 -- Architecture globale du système CleanCity (vue contexte et conteneurs)"
Bullet "Figure 2 -- Diagramme de cas d'utilisation"
Bullet "Figure 3 -- Diagramme de classes (modèle de données applicatif)"
Bullet "Figure 4 -- Diagramme entite-relation de la base de données"
Bullet "Figure 5 -- Diagramme de séquence : cycle de vie d'un signalement de déchet"
Bullet "Figure 6 -- Arborescence du code source de l'application Flutter"
Bullet "Figure 7 -- Pipeline d'intégration et de déploiement continu (CI/CD)"
Blank
H1 "Liste des tableaux"
Bullet "Tableau 1 -- Comparaison entre le signalement traditionnel et le signalement via CleanCity"
Bullet "Tableau 2 -- Acteurs du système et besoins associés"
Bullet "Tableau 3 -- Spécifications fonctionnelles retenues"
Bullet "Tableau 4 -- Spécifications non fonctionnelles retenues"
Bullet "Tableau 5 -- Comparaison entre une architecture Backend-as-a-Service et un backend développé sur mesure"
Bullet "Tableau 6 -- Dictionnaire de données des tables principales"
Bullet "Tableau 7 -- Synthèse des politiques de sécurité (Row Level Security) par table"
Bullet "Tableau 8 -- Principales dépendances techniques du projet"
Bullet "Tableau 9 -- Scénarios de test fonctionnels et résultats"
Bullet "Tableau 10 -- Étapes du pipeline CI/CD GitHub Actions"
PageBreak

# ============================================================================
# TABLE DES MATIERES (champ TOC réel)
# ============================================================================
H1 "Table des matieres"
$tocRange = $sel.Range
$toc = $doc.TablesOfContents.Add($tocRange, $true, 1, 3)
$sel.EndKey(6) | Out-Null
P "[Champ Word -- clic droit puis 'Mettre a jour les champs' pour actualiser la pagination avant impression.]"
PageBreak

# ============================================================================
# INTRODUCTION GÉNÉRALE
# ============================================================================
H1 "Introduction générale"
P "La croissance urbaine que connaissent les principales villes camerounaises -- Douala, Yaounde, Bafoussam ou Garoua -- s'accompagne d'une production de déchets solides en hausse constante, que les dispositifs municipaux de collecte peinent a absorber intégralement. Dans de nombreux quartiers, en particulier les zones a habitat spontane et les periph eries en expansion rapide, l'absence de points de collecte réguliers favorise l'apparition de décharges sauvages, avec des conséquences directes sur la salubrite publique, l'écoulement des eaux pluviales et la santé des populations."
P "Face a ce constat, le numérique constitué un levier de plus en plus mobilise a travers le monde pour ameliorer la gestion urbaine : géolocalisation des signalements citoyens, suivi en temps réel des équipes de terrain, tableaux de bord pour les décideurs municipaux. C'est dans cette perspective que s'inscrit le projet CleanCity, une application mobile et web dont l'objectif est de digitaliser et de fluidifier la chaine qui va du signalement d'un déchet par un citoyen jusqu'a sa collecte, son traitement et sa valorisation par un centre de tri, en passant par la coordination des collecteurs de terrain."
P "Le present mémoire a pour objectif de rendre compte de manière structurée de l'ensemble de la démarche d'ingenierie logicielle ayant conduit a la réalisation de CleanCity, depuis l'analyse du contexte et l'expression des besoins jusqu'au déploiement de l'application, en passant par la conception architecturale, le choix des technologies et la validation par les tests. Il est organisé en sept chapitres."
P "Le premier chapitre présente le contexte géographique et la problématique locale qui motivent le projet. Le deuxième chapitre exposé le cahier des charges fonctionnel et technique, en identifiant les acteurs du système et leurs besoins. Le troisième chapitre est consacre a l'analyse et a la conception du système : architecture globale, modélisation des données et diagrammes UML. Le quatrième chapitre détaillé la réalisation technique et les choix technologiques operes. Le cinquième chapitre présente la stratégie de test adoptee et ses résultats. Le sixième chapitre decrit le processus de déploiement et les mesures de sécurisation mises en place. Enfin, le septième chapitre dresse un bilan critique du projet et ouvre des perspectives d'évolution, avant une conclusion générale."
PageBreak

# ============================================================================
# CHAPITRE 1
# ============================================================================
H1 "Chapitre 1 -- Contexte du projet et problématique locale"

H2 "1.1 Contexte géographique et socio-urbain du Cameroun"
P "Le Cameroun, souvent qualifie d''Afrique en miniature' en raison de sa diversite géographique et culturelle, connaît depuis plusieurs décennies une urbanisation rapide et largement non planifiée. Les deux principales métropoles, Douala (capitale économique) et Yaounde (capitale politique), concentrent une part croissante de la population nationale, a laquelle s'ajoutent des villes secondaires en expansion telle que Bafoussam, Bamenda, Garoua ou Maroua. Cette dynamique urbaine, si elle témoigne d'un dynamisme économique et démographique réel, se heurte a des infrastructures de base -- voirie, assainissement, gestion des déchets -- dont le développement ne suit pas toujours le meme rythme."
P "Dans ce contexte, la gestion des déchets solides urbains constitué un défi structurel partage par de nombreuses villes d'Afrique subsaharienne : les circuits de collecte formels, souvent gérés par des prestataires municipaux ou des délégataires de service public, coexistent avec des pratiques informelles de dépôt dans des espaces non aménagés (terrains vagues, abords de cours d'eau, bas-fonds). Ce phénomène est documenté de manière récurrente par les organismes internationaux tels que l'ONU-Habitat ou la Banque mondiale dans leurs rapports sur la gestion des déchets solides en Afrique subsaharienne, qui soulignent le lien entre insuffisance de la collecte, déficit d'infrastructures et risques sanitaires et environnementaux accrus (inondations liées a l'obstruction des drains, proliferation de vecteurs de maladies)."
P "[Note méthodologique : l'étudiant est invite a compléter ce paragraphe avec des données chiffrees actualisées et sourcées, par exemple issues de l'Institut National de la Statistique du Cameroun, du Ministere de l'Environnement, de la Protection de la Nature et du Développement Durable (MINEPDED), ou de rapports d'organismes internationaux spécifiques a la ou aux villes étudiées dans le cadre du projet.]"

H2 "1.2 État des lieux de la gestion des déchets dans les villes camerounaises"
P "La chaine de gestion des déchets, dans son fonctionnement traditionnel, repose généralement sur les étapes suivantes : dépôt du déchet par le ménage ou l'entreprise génératrice, collecte par un opérateur (souvent selon un circuit et un calendrier fixes), transport vers un site de transfert ou de traitement, puis enfouissement, incineration ou valorisation. Ce modèle, largement linéaire, présente plusieurs limités dans le contexte camerounais : couverture géographique incomplete de la collecte régulière, absence de canal simple permettant a un citoyen de signaler un point de décharge sauvage en dehors des circuits prévus, et manque de visibilite, pour les autorites comme pour les opérateurs, sur l'état réel du territoire a un instant donne."
P "A cela s'ajoute une dimension économique et sociale importante : une partie non négligeable de la collecte et du tri s'effectue de manière informelle, par des acteurs individuels qui récupèrent des matériaux valorisables (plastique, metal, papier) sans cadre structure de rémunération ni de traçabilité. Cette économie informelle, bien que porteuse d'un potentiel de valorisation réel, souffre d'un manque de reconnaissance, de sécurité et de visibilite qui limité son impact positif sur la salubrite urbaine."

H2 "1.3 Problématique : l'absence de suivi numérique en temps réel"
P "La problématique centrale de ce projet peut se formuler ainsi : comment permettre a un citoyen de signaler rapidement et précisément un problème de salubrite (déchet non collecte, décharge sauvage), tout en offrant aux acteurs de la collecte et du traitement -- collecteurs de terrain, centres de tri, autorites -- une visibilite en temps réel sur l'ensemble des signalements, leur localisation et leur statut de traitement ?"
P "En l'absence d'un tel dispositif numérique, plusieurs conséquences sont observées : les signalements informels (appel téléphonique, réseaux sociaux, bouche-a-oreille) se perdent ou ne sont pas centralisés ; les collecteurs ne disposent pas d'une vue d'ensemble des zones prioritaires ; les centres de tri ne peuvent pas anticiper les volumes et types de déchets a recevoir ; enfin, il n'existe aucune traçabilité permettant de mesurer objectivement la performance du système de collecte (délai moyen de traitement, volumes collectes par zone, taux de valorisation)."
P "C'est cette absence d'outil numérique de suivi, de géolocalisation et de coordination en temps réel entre les différents acteurs de la chaine de gestion des déchets qui constitué le coeur de la problématique traitée par le projet CleanCity."

H2 "1.4 Objectifs du projet CleanCity"
P "Le projet CleanCity poursuit un objectif général : concevoir et développer une plateforme numérique, accessible via mobile (Android, iOS) et via le web, permettant de digitaliser l'ensemble du cycle de vie d'un signalement de déchet, depuis sa création par un citoyen jusqu'a sa valorisation par un centre de tri, en passant par sa prise en charge par un collecteur."
Bullet "Permettre a tout citoyen de signaler, en quelques étapes, un déchet ou une décharge sauvage en y associant une localisation GPS précise et des photographies."
Bullet "Offrir aux collecteurs un tableau de bord des missions disponibles, localisées sur une carte, avec la possibilite d'accepter, de suivre et de cloturer une mission de collecte."
Bullet "Permettre aux centres de tri de confirmer la reception des déchets collectes, d'en saisir le poids réel et de déclencher, le cas echeant, une rémunération liée a la valorisation (système de points écologiques convertibles)."
Bullet "Fournir aux administrateurs de la plateforme une vue d'ensemble des utilisateurs, des signalements et des demandes de paiement, avec les outils de supervision nécessaires."
Bullet "Favoriser, a travers un système de points écologiques et un mécanisme de retrait par mobile money, une incitation économique a la collecte et au tri des déchets valorisables."

H2 "1.5 Vision et valeurs du projet"
P "CleanCity s'inscrit dans une démarche de développement durable resumee par sa signature : « Collect - Recover - Preserve » (Collecter - Valoriser - Preserver). Cette formule traduit une vision en trois temps : collecter les déchets la ou ils se trouvent grâce a la participation citoyenne, valoriser les matieres récupérables au sein de centres de tri partenaires, et preserver ainsi l'environnement urbain et la santé publique."
P "Au-dela de l'aspect technique, le projet porte une ambition sociale et environnementale : rendre visible un problème souvent subi en silence par les populations, structurer une économie de la collecte aujourd'hui largement informelle, et outiller les acteurs locaux -- citoyens, collecteurs, centres de tri, autorites -- d'un langage commun autour de la donnée géolocalisée."

Tbl @("Critere","Signalement traditionnel","Signalement via CleanCity") @(
    @("Canal de signalement","Appel téléphonique, bouche-a-oreille, réseaux sociaux","Application mobile / web dediee"),
    @("Localisation","Description approximative, non standardisee","Coordonnées GPS précises rattachees a une adresse"),
    @("Traçabilité du statut","Aucune visibilite pour le citoyen apres signalement","Statuts suivis en temps réel (en attente, accepte, collecte, livre)"),
    @("Preuve visuelle","Rarement disponible","Photographies jointes au signalement"),
    @("Coordination des collecteurs","Manuelle, non centralisee","Missions visibles sur une carte, attribuees et suivies"),
    @("Mesure de la performance","Non mesurable objectivement","Historique exploitable (délais, volumes, statuts)"),
    @("Incitation a la collecte","Absente ou informelle","Points écologiques et retrait par mobile money")
)
Caption "Tableau 1 -- Comparaison entre le signalement traditionnel et le signalement via CleanCity"
PageBreak

# ============================================================================
# CHAPITRE 2
# ============================================================================
H1 "Chapitre 2 -- Cahier des charges fonctionnel et technique"

H2 "2.1 Expression des besoins"
P "L'analyse des besoins a été conduite en identifiant quatre catégories d'acteurs directement impliqués dans l'usage de la plateforme, chacune correspondant a un rôle applicatif distinct dans le système CleanCity (champ rôle de la table users : generator, collector, center, admin)."
Tbl @("Acteur","Rôle applicatif","Besoins principaux") @(
    @("Citoyen / générateur de déchets","generator","Signaler rapidement un déchet avec photo et localisation ; suivre le statut de ses signalements ; etre notifie de la prise en charge ; contacter le collecteur."),
    @("Collecteur","collector","Consulter les missions disponibles sur une carte ; accepter une mission ; marquer la collecte et la livraison ; communiquer avec le générateur ; suivre sa rémunération."),
    @("Centre de tri","center","Recevoir les livraisons associées a son centre ; confirmer la reception et saisir le poids réel ; enregistrer un événement de traitement ; déclencher le credit de points au collecteur."),
    @("Administrateur","admin","Superviser l'ensemble des utilisateurs et des signalements ; valider ou rejeter les demandes de retrait (payout) ; disposer d'une vue statistique globale de la plateforme.")
)
Caption "Tableau 2 -- Acteurs du système et besoins associés"
P "Cette structuration en quatre rôles distincts, portee au niveau de la base de données par le type énuméré user_role, permet d'appliquer des règles d'accès différenciées (voir 3.4) et de proposer, au sein d'une seule et meme application, des parcours utilisateurs adaptés a chaque profil."

H2 "2.2 Spécifications fonctionnelles"
P "Les spécifications fonctionnelles retenues couvrent l'ensemble du cycle de vie d'un signalement de déchet, de sa création a sa valorisation, ainsi que les fonctionnalités transverses (authentification, messagerie, notifications)."
Tbl @("Référence","Fonctionnalité","Description sommaire") @(
    @("FR-01","Authentification multi-canal","Inscription et connexion par email/mot de passe, par compte Google (OAuth), ou par numero de téléphone (code OTP)."),
    @("FR-02","Sélection et verrouillage du rôle","Choix du rôle applicatif a la première connexion ; modification ultérieure réservée a l'administrateur (règle métier enforce_role_change)."),
    @("FR-03","Création d'un signalement géolocalisé","Saisie du type de déchet, de la quantite estimée, de l'adresse et d'un créneau horaire, avec capture automatique des coordonnées GPS."),
    @("FR-04","Ajout de photographies","Prise ou sélection d'une photo jointe au signalement, hebergee dans le stockage Supabase."),
    @("FR-05","Visualisation cartographique","Affichage des signalements et des missions sur une carte interactive (fond de carte Mapbox)."),
    @("FR-06","Recherche géographique de proximite","Recherche des signalements en attente dans un rayon donne autour d'une position, via la fonction PostGIS nearby_waste_requests."),
    @("FR-07","Prise en charge d'une mission","Acceptation d'un signalement par un collecteur, avec verrouillage pour éviter une double affectation."),
    @("FR-08","Suivi du statut de collecte","Mise a jour du statut du signalement (en attente, accepte, collecte, livre, annule) visible par toutes les parties prenantes."),
    @("FR-09","Reception et pesee au centre de tri","Confirmation de reception, saisie du poids réel et enregistrement d'un événement de traitement."),
    @("FR-10","Système de points écologiques","Credit automatique de points au collecteur en fonction du type et du poids de déchet valorisé."),
    @("FR-11","Demande de retrait Mobile Money","Conversion des points en un montant en francs CFA (XAF) et demande de retrait via un opérateur de mobile money, validée par un administrateur."),
    @("FR-12","Messagerie instantanee","Échange de messages entre générateur et collecteur, dans le cadre d'un signalement ou en conversation directe."),
    @("FR-13","Notifications push","Notification des utilisateurs concernés a chaque changement d'état significatif (nouvelle mission, mission acceptee, paiement recu)."),
    @("FR-14","Espace d'administration","Gestion des utilisateurs, supervision des signalements et validation des demandes de retrait par l'administrateur.")
)
Caption "Tableau 3 -- Spécifications fonctionnelles retenues"

H2 "2.3 Spécifications non fonctionnelles"
P "Au-dela des fonctionnalités métier, plusieurs exigences non fonctionnelles ont guide les choix d'architecture et d'implémentation, en tenant compte des contraintes spécifiques du contexte camerounais, notamment la variabilite de la qualite de connexion internet en dehors des grands centres urbains."
Tbl @("Catégorie","Exigence","Justification") @(
    @("Performance","Temps de réponse acceptable sur les opérations courantes (chargement de la carte, liste des missions) meme en connexion mobile 3G/4G limitée.","Une partie significative des utilisateurs accede a l'application via des réseaux mobiles dont le debit est variable selon les zones."),
    @("Sécurité des données","Isolation stricte des données par utilisateur et par rôle via des politiques Row Level Security au niveau de la base de données.","Éviter qu'un utilisateur puisse consulter ou modifier des données ne le concernant pas, independamment de la couche applicative."),
    @("Accessibilite / faible connectivite","Conception d'interfaces légères, limitation du poids des images transmises, gestion explicite des erreurs réseau.","Certaines zones peri-urbaines et rurales camerounaises presentent une connectivite internet intermittente."),
    @("Ergonomie mobile","Interface adaptée a une utilisation tactile, parcours simplifies pour un public non nécessairement familier avec les outils numériques.","Le succes de l'adoption citoyenne depend directement de la simplicite du parcours de signalement."),
    @("Multiplateforme","Une base de code unique déployable sur Android, iOS et Web.","Reduire les couts de développement et de maintenance tout en maximisant la couverture d'utilisateurs potentiels."),
    @("Disponibilite","Recours a une infrastructure cloud managee (Supabase) offrant une disponibilite élevée sans gestion d'infrastructure dediee.","Le porteur de projet, dans un contexte de mémoire de fin d'études, ne dispose pas d'une équipe d'exploitation dediee."),
    @("Localisation linguistique","Interface et messages en français, avec un champ preferred_language pour une extension future multilingue.","Le français est la langue d'usage principale du public cible dans les zones concernées.")
)
Caption "Tableau 4 -- Spécifications non fonctionnelles retenues"

H2 "2.4 Contraintes et périmètre du projet"
P "Le périmètre du projet a été volontairement circonscrit afin de rester compatible avec le cadre temporel d'un mémoire de licence. Sont ainsi inclus dans le périmètre : le cycle complet signalement-collecte-traitement, l'authentification multi-canal, la cartographie, la messagerie et le système de points écologiques. En sont exclus, a ce stade, l'intégration réelle d'une passerelle de paiement mobile money (le mécanisme actuel repose sur une demande de retrait validée manuellement par un administrateur) et le mode de fonctionnement entièrement hors connexion, qui constituent des pistes d'évolution présentées au chapitre 7."
PageBreak

# ============================================================================
# CHAPITRE 3
# ============================================================================
H1 "Chapitre 3 -- Analyse et conception"

H2 "3.1 Architecture globale du système"
P "L'architecture de CleanCity repose sur un modèle client-serveur classique, dans lequel le client -- l'application Flutter -- concentre l'ensemble de la logique de présentation et de navigation, tandis que le serveur -- la plateforme Supabase -- assume les responsabilités de persistance, d'authentification, de stockage de fichiers et de sécurité d'accès. Cette répartition permet de déployer une base de code Dart unique sur trois cibles (Android, iOS, Web) sans dupliquer la logique métier cote serveur."
P "Le client communique avec Supabase via une API REST auto-générée (PostgREST) au-dessus de la base PostgreSQL, ainsi que via les SDK dedies a l'authentification et au stockage de fichiers. Deux services tiers completent l'architecture : Mapbox, pour la fourniture des fonds de carte et des tuiles cartographiques affichees dans le composant CleanCityMapView, et OneSignal, pour l'envoi des notifications push aux utilisateurs concernés par un changement de statut."
Callout "Figure 1" "Diagramme d'architecture (vue C4 - niveau Contexte et niveau Conteneurs) : au centre, l'application CleanCity (client Flutter mobile + web) ; autour, les acteurs (générateur, collecteur, centre de tri, administrateur) et les systèmes externes (Supabase : Auth, PostgreSQL, Storage, Realtime ; Mapbox ; OneSignal ; GitHub Actions pour le CI/CD). Source Mermaid disponible dans docs/DIAGRAMMES_UML_C4.md (sections 4.1 et 4.2), a exporter en image via mermaid.live avant insertion."

H2 "3.2 Modélisation des données et choix de Supabase"
P "Le choix d'une architecture de type Backend-as-a-Service (BaaS), en l'occurrence Supabase, s'est impose au regard des contraintes de temps et de ressources propres a un projet de fin d'études. Supabase fournit, au-dessus d'une base PostgreSQL standard, un ensemble de services intégrés -- authentification (email, OAuth, OTP téléphonique), API REST auto-générée, stockage de fichiers avec règles d'accès, souscriptions en temps réel -- qui auraient nécessite, dans une approche de backend développé sur mesure, un investissement de développement et d'exploitation nettement plus important."
P "Un autre argument déterminant en faveur de Supabase est la disponibilite native de l'extension PostGIS, qui permet de stocker des coordonnées géographiques sous forme de colonnes de type geography et d'exécuter directement, cote base de données, des requetes de proximite spatiale performantes (fonction ST_DWithin, tri par distance via l'opérateur <->). Cette approche évite de dupliquer une logique de calcul géographique cote client et garantit la cohérence des résultats quelle que soit la plateforme d'accès (mobile ou web)."
Tbl @("Critere","Backend-as-a-Service (Supabase)","Backend développé sur mesure") @(
    @("Délai de mise en oeuvre","Court : authentification, API et stockage disponibles des la création du projet","Long : nécessite de développer et de sécuriser chaque brique (auth, API, stockage)"),
    @("Cout d'infrastructure","Mutualisé, adapté a un usage naissant (offre gratuite / faible cout au démarrage)","Nécessite un serveur ou une infrastructure cloud dediee des le depart"),
    @("Sécurité d'accès","Gérée au plus pres de la donnée via des politiques Row Level Security","A implémenter intégralement au niveau applicatif ou via un middleware dedie"),
    @("Fonctions géospatiales","PostGIS integre nativement a PostgreSQL","Nécessite l'installation et la maintenance d'une extension ou d'un service dedie"),
    @("Maintenance et exploitation","Assurees par le fournisseur (mises a jour, sauvegardes, disponibilite)","A la charge intégrale de l'équipe projet"),
    @("Flexibilite / personnalisation","Bonne, via fonctions SQL et RPC personnalisées, mais dependante des capacités de la plateforme","Totale, au prix d'un effort de développement plus conséquent")
)
Caption "Tableau 5 -- Comparaison entre une architecture Backend-as-a-Service et un backend développé sur mesure"

H2 "3.3 Structure de la base de données"
P "Le schema de la base de données, defini dans le fichier lib/supabase/schema.sql, s'articule autour de onze tables principales couvrant l'ensemble du cycle fonctionnel de l'application : gestion des profils utilisateurs, des adresses géolocalisées, des signalements de déchets, des missions de collecte, des événements de traitement, des transactions de points écologiques, des demandes de retrait et de la messagerie."
Tbl @("Table","Champs clés","Rôle dans le système") @(
    @("users","id, rôle, full_name, phone_e164, role_confirmed_at","Profil applicatif de chaque utilisateur, lié a auth.users ; porte le rôle (generator, collector, center, admin)."),
    @("addresses","id, user_id, latitude, longitude, location (geography)","Adresses géolocalisées ; la colonne location est calculee automatiquement a partir de latitude/longitude via PostGIS."),
    @("waste_requests","id, generator_id, address_id, center_id, waste_type, status","Signalement de déchet : entite centrale du système, avec son statut (pending, accepted, collected, delivered, cancelled)."),
    @("pickups","request_id, collector_id, accepted_at, collected_at, delivered_at","Mission de collecte associée a un signalement, portee par un collecteur."),
    @("waste_request_photos","id, request_id, uploaded_by, url","Photographies associées a un signalement, stockees dans Supabase Storage."),
    @("processing_events","id, request_id, center_id, weighed_kg, accepted","Événement de pesee et de validation d'un signalement par un centre de tri."),
    @("eco_transactions","id, user_id, request_id, points, reason","Historique des points écologiques credites a un utilisateur."),
    @("payout_requests","id, user_id, provider, phone, amount_xaf, status","Demande de retrait des points convertis en francs CFA via un opérateur de mobile money."),
    @("chat_threads / chat_thread_members / chat_messages","id, kind, request_id / thread_id, user_id / sender_id, body","Messagerie liée a un signalement (kind = request) ou conversation directe (kind = direct).")
)
Caption "Tableau 6 -- Dictionnaire de données des tables principales"
Callout "Figure 3 et Figure 4" "Diagramme de classes du modèle applicatif (AppUser, WasteRequest, Pickup, Address, WasteRequestPhoto, ProcessingEvent, EcoTransaction, PayoutRequest et leurs services associés) et diagramme entite-relation de la base de données, tous deux disponibles au format Mermaid dans docs/DIAGRAMMES_UML_C4.md (sections 2 et 5)."
P "Un point de conception notable concerné la colonne location de la table addresses, définie comme une colonne générée (generated always as ... stored) : elle est recalculee automatiquement par PostgreSQL a chaque insertion ou mise a jour des colonnes latitude et longitude, garantissant qu'aucune incohérence ne puisse exister entre les coordonnées brutes et leur représentation géographique. Cette colonne est indexée au moyen d'un index spatial GiST (addresses_location_gix), condition nécessaire a la performance des requetes de proximite."
P "La recherche de signalements a proximite d'une position donnée est encapsulée dans une fonction serveur dediee, nearby_waste_requests(lat, lng, radius_meters), qui combine un filtre sur le statut du signalement (pending), une clause de distance ST_DWithin exprimee en metres, et un tri par distance croissante via l'opérateur PostGIS <->. Cette logique, exécutée directement dans la base de données, offre de meilleures performances qu'une implémentation cote client et demeure independante de la plateforme consommatrice (mobile ou web)."

H2 "3.4 Sécurité des données : Row Level Security"
P "La sécurité d'accès aux données constitué un axe de conception a part entière. Plutot que de reposer uniquement sur des contrôlés réalisés cote application -- par nature contournables si un utilisateur malveillant interagit directement avec l'API -- CleanCity applique le principe de defense en profondeur en activant les politiques Row Level Security (RLS) de PostgreSQL sur l'intégralité des tables applicatives. Chaque requete émise, y compris via l'API REST auto-générée, est ainsi filtree au niveau du moteur de base de données en fonction de l'identite de l'utilisateur authentifie (auth.uid())."
P "Deux fonctions utilitaires, exécutées en mode SECURITY DEFINER pour éviter les recursions de politiques, structurent l'ensemble des règles d'accès : current_user_role(), qui retourne le rôle de l'utilisateur courant, et is_request_participant(request_id), qui détermine si l'utilisateur courant est partie prenante d'un signalement donne (générateur, collecteur assigne ou centre destinataire). Un déclencheur (enforce_role_change) empêche par ailleurs un utilisateur de modifier lui-meme son rôle applicatif une fois celui-ci confirme, cette opération etant réservée a l'administrateur."
Tbl @("Table","Politique principale","Règle appliquee") @(
    @("users","users_update_self_or_admin","Un utilisateur ne peut modifier que son propre profil, sauf s'il est administrateur."),
    @("waste_requests","waste_requests_update_owner_or_agent","Modification réservée au générateur, au collecteur assigne, ou a un centre/administrateur."),
    @("pickups","pickups_select_participant","Lecture réservée au collecteur, au centre concerné, au générateur du signalement, ou a l'administrateur."),
    @("waste_request_photos","photos_select_participant","Lecture et dépôt réservés aux participants du signalement (via is_request_participant)."),
    @("eco_transactions","eco_transactions_insert_agent","Seul un centre de tri ou un administrateur peut crediter des points a un utilisateur."),
    @("payout_requests","payout_requests_update_admin","Seul un administrateur peut faire évoluer le statut d'une demande de retrait."),
    @("chat_messages","chat_messages_insert_member","Un message ne peut etre envoye que par un membre du fil de discussion concerné."),
    @("storage.objects (request_photos)","storage_request_photos_participant_read/write","Accès aux photos d'un signalement réservé aux participants de ce signalement.")
)
Caption "Tableau 7 -- Synthèse des politiques de sécurité (Row Level Security) par table"

H2 "3.5 Diagrammes UML complémentaires"
P "Afin de documenter le comportement dynamique du système, deux catégories de diagrammes complémentaires ont été produites : un diagramme de cas d'utilisation, formalisant les interactions entre les quatre acteurs identifiés et les fonctionnalités du système, et un ensemble de diagrammes de séquence, illustrant le cheminement d'un signalement de sa création a sa valorisation."
Callout "Figure 2" "Diagramme de cas d'utilisation regroupant les acteurs Générateur, Collecteur, Centre de tri et Administrateur autour des cas d'utilisation Authentification, Signalements, Missions et Administration (source Mermaid : docs/DIAGRAMMES_UML_C4.md, section 1)."
Callout "Figure 5" "Diagramme de séquence du cycle de vie complet d'un signalement : (1) création par le générateur avec capture GPS et upload photo, (2) acceptation de la mission par un collecteur, (3) marquage collecte puis livraison au centre, (4) reception, pesee et credit de points par le centre de tri, (5) demande de retrait Mobile Money validée par l'administrateur (source Mermaid : docs/DIAGRAMMES_UML_C4.md, section 3)."
P "Le passage d'un signalement par les statuts pending, accepted, collected puis delivered materialise ainsi une machine a états simple mais rigoureuse, dont chaque transition est contrôlée a la fois par la logique applicative (écrans et services Flutter) et par les politiques RLS présentées en 3.4, garantissant qu'aucune transition ne puisse etre déclenchée par un acteur non habilite."
PageBreak

# ============================================================================
# CHAPITRE 4
# ============================================================================
H1 "Chapitre 4 -- Technologies et réalisation"

H2 "4.1 Choix de la stack technique"
P "Le choix technologique central du projet est celui du framework Flutter (SDK Dart ^3.6.0), retenu pour sa capacité a produire, a partir d'une base de code unique écrite en Dart, des applications natives Android et iOS ainsi qu'une application Web, sans sacrifier les performances ni la cohérence visuelle entre plateformes. Ce choix répond directement a une exigence non fonctionnelle du cahier des charges (2.3) : maximiser la couverture d'utilisateurs -- citoyens équipes de smartphones Android, collecteurs et centres pouvant preferer un usage web sur poste fixe -- avec un effort de développement mutualisé."
P "La navigation applicative repose sur le package go_router, qui structure les différents parcours (authentification, tableau de bord générateur, collecteur, centre, administration) sous forme de routes declaratives, facilitant la gestion des redirections liées au rôle de l'utilisateur connecte. La gestion d'état transverse (theme clair/sombre notamment) s'appuie sur le package provider, dans une architecture volontairement simple au regard du périmètre fonctionnel du projet."
Tbl @("Dépendance","Rôle dans l'application") @(
    @("supabase_flutter","Client officiel Supabase : authentification, requetes PostgREST, stockage, souscriptions temps réel."),
    @("go_router","Navigation declarative et gestion des routes selon le rôle de l'utilisateur."),
    @("provider","Gestion d'état transverse (theme, état d'authentification)."),
    @("flutter_map + latlong2","Affichage de cartes interactives et de marqueurs géolocalisés."),
    @("geolocator","Accès a la position GPS de l'appareil."),
    @("image_picker","Sélection ou capture de photographies pour les signalements."),
    @("mime","Detection du type MIME des fichiers avant upload vers le stockage."),
    @("onesignal_flutter","Intégration du service de notifications push OneSignal."),
    @("google_fonts","Typographies coherentes avec la charte graphique de l'application."),
    @("http","Requetes HTTP complémentaires vers des services externes.")
)
Caption "Tableau 8 -- Principales dépendances techniques du projet"

H2 "4.2 Backend-as-a-Service : Supabase en pratique"
P "L'intégration de Supabase s'articule autour de quatre briques principales, initialisees au démarrage de l'application dans lib/supabase/supabase_config.dart puis consommees par des services dedies (AppUserService, WasteRequestService, PayoutRequestService, ChatService). L'authentification est gérée par le module Supabase Auth, qui prend en charge l'inscription par email et mot de passe, la connexion via un fournisseur OAuth Google, et la vérification par code a usage unique (OTP) envoye par SMS pour les connexions par numero de téléphone."
P "Le stockage des fichiers repose sur deux buckets distincts : user_uploads, public en lecture, dedie aux avatars des utilisateurs, et request_photos, prive et soumis a une politique d'accès restreignant la lecture et l'écriture aux seuls participants du signalement concerné (voir 3.4). Cette séparation traduit, au niveau du stockage de fichiers, la meme logique de moindre privilège que celle appliquee aux tables de la base de données."
P "Enfin, la fonction RPC nearby_waste_requests, appelee depuis le service applicatif de recherche géographique, illustre l'usage de fonctions SQL personnalisées exposées via l'API Supabase : plutot que de rapatrier l'ensemble des signalements pour les filtrer cote client, l'application delegue le calcul de proximite géographique a la base de données elle-meme, ce qui reduit a la fois la quantite de données transferees -- un enjeu important en contexte de connectivite limitée -- et le temps de traitement."

H2 "4.3 Intégration cartographique"
P "La visualisation cartographique, portee par le composant partage CleanCityMapView, s'appuie sur le package flutter_map associé a des tuiles vectorielles fournies par l'API Static Tiles de Mapbox. Ce choix fait suite a une première tentative d'intégration du SDK natif mapbox_maps_flutter, dont la compatibilité se limitait aux plateformes Android et iOS ; l'adoption de flutter_map, alimente par les tuiles Mapbox via une simple URL de tuiles parametree par un jeton d'accès (MAPBOX_ACCESS_TOKEN), a permis d'obtenir un rendu cartographique cohérent sur les trois plateformes cibles, y compris le Web."
P "Un mécanisme de repli (fallback) a été prévu : en l'absence de jeton Mapbox configure, l'application bascule automatiquement sur les tuiles publiques d'OpenStreetMap, garantissant qu'une carte reste toujours affichee, y compris en environnement de développement ou de demonstration ne disposant pas encore d'une clé Mapbox validé."
Callout "Figure 6" "Capture d'écran de l'écran carte (CleanCityMapView) affichant les signalements en attente sous forme de marqueurs colores, a inserer depuis l'application en cours d'exécution."

H2 "4.4 Notifications push"
P "La notification des utilisateurs lors des changements d'état significatifs (nouvelle mission disponible, mission acceptee, paiement recu) est assuree par le service PushNotificationService, qui encapsule l'intégration du SDK OneSignal. Ce choix permet de bénéficier d'une gestion centralisee des jetons d'appareils et des segments d'audience, sans avoir a développer une infrastructure de notification dediee (serveur de push, gestion des certificats Apple Push Notification service, etc.)."

H2 "4.5 Gestion de version avec GitHub"
P "Le développement du projet est versionne sur GitHub, avec une branche principale (main) servant de référence stable et de base au déclenchement du pipeline d'intégration continue. L'historique de commits du projet illustre une progression itérative caracteristique d'un développement de mémoire de fin d'études : mise en place initiale du projet et des pipelines CI/CD, correctifs de build (par exemple la mise a jour du package google_fonts), puis une refonte majeure du backend autour de Supabase et PostGIS accompagnee de la migration de la couche cartographique vers Mapbox."
P "Cette organisation, bien que simplifiee par rapport a un flux de travail Gitflow complet (absence de branches de fonctionnalités systematiques dans l'historique observe), a permis de maintenir a tout moment une branche principale compilable, condition nécessaire au bon fonctionnement du pipeline de build automatise decrit au chapitre 6."

H2 "4.6 Organisation du code source"
P "Le code source de l'application est organisé en modules correspondant aux rôles applicatifs et aux domaines fonctionnels, favorisant la lisibilite et la maintenabilite du projet malgre l'absence d'une architecture en couches strictement decoupee (par exemple de type Clean Architecture)."
Callout "Figure 7" "Arborescence du dossier lib/ : auth/, generator/, collector/, center/, admin/, chat/ (écrans par rôle et par domaine) ; models/ (AppUser, WasteRequest, PayoutRequest) ; services/ (AppUserService, WasteRequestService, ChatService, MediaUploadService, PushNotificationService, MapsService) ; components/ (widgets partages dont CleanCityMapView) ; supabase/ (configuration et schema.sql) ; nav.dart (configuration go_router) ; main.dart (point d'entree)."
P "Cette organisation par rôle (auth, generator, collector, center, admin, chat) plutot que par couche technique présente l'avantage de regrouper, pour chaque profil d'utilisateur, l'ensemble des écrans qui le concernent, facilitant la comprehension du parcours utilisateur correspondant lors de la maintenance ou de l'ajout de nouvelles fonctionnalités."
PageBreak

# ============================================================================
# CHAPITRE 5
# ============================================================================
H1 "Chapitre 5 -- Phase de tests"

H2 "5.1 Stratégie de tests"
P "La validation de CleanCity a été conduite selon trois niveaux complémentaires. Les tests unitaires, écrits avec le package flutter_test, portent sur la logique pure des modèles de données (méthodes fromJson/toJson et copyWith des classes AppUser, WasteRequest, PayoutRequest) ainsi que sur les fonctions utilitaires ne dependant pas d'un état d'interface (calculs liés aux points écologiques, formatage des libelles de rôle)."
P "Les tests d'intégration visent a vérifier le comportement du système au niveau de la base de données, en particulier le respect effectif des politiques Row Level Security présentées en 3.4 : chaque règle d'accès a été contrôlée en tentant, avec des comptes de test associés a des rôles différents, des opérations autorisees et des opérations qui doivent etre refusees (par exemple, un générateur tentant de modifier le signalement d'un autre utilisateur, ou un collecteur tentant de crediter des points sans etre rattache a un centre)."
P "Enfin, les tests d'interface utilisateur ont été réalisés de manière manuelle et exploratoire, en parcourant l'ensemble des scénarios utilisateurs clés sur emulateur Android, sur navigateur Web et, dans la mesure du possible, sur un appareil physique, afin de valider a la fois le fonctionnement fonctionnel et l'ergonomie des parcours (voir 2.3, exigences non fonctionnelles d'ergonomie mobile)."

H2 "5.2 Scénarios de test et résultats"
P "Le tableau suivant synthetise un extrait représentatif des scénarios de test executes au cours du projet, couvrant les principales fonctionnalités et règles de sécurité du système."
Tbl @("ID","Scénario","Résultat attendu","Statut") @(
    @("T-01","Inscription par email puis sélection du rôle générateur","Compte créé, profil provisionné automatiquement (handle_new_auth_user), rôle enregistre","Réussi"),
    @("T-02","Tentative de modification du rôle par l'utilisateur lui-meme apres confirmation","Opération rejetee (ROLE_ALREADY_CONFIRMED) sauf pour un administrateur","Réussi"),
    @("T-03","Création d'un signalement avec photo et localisation GPS","Signalement, adresse et photo enregistres ; statut initial pending","Réussi"),
    @("T-04","Recherche de signalements a proximite (rayon 5 km)","Liste triee par distance croissante via nearby_waste_requests","Réussi"),
    @("T-05","Acceptation d'une mission par deux collecteurs simultanement","Un seul enregistrement pickups accepte, le second rejete","Réussi"),
    @("T-06","Marquage collecte puis livraison au centre selectionne","Statut du signalement mis a jour successivement en collected puis delivered","Réussi"),
    @("T-07","Lecture d'un signalement par un utilisateur non participant","Accès en lecture aux photos et événements de traitement refuse par RLS","Réussi"),
    @("T-08","Pesee et validation par le centre de tri","Enregistrement processing_events créé, credit de points écologiques au collecteur","Réussi"),
    @("T-09","Credit de points en double pour un meme signalement","Contrainte unique (user_id, request_id, reason) empêchant le doublon","Réussi"),
    @("T-10","Demande de retrait Mobile Money par un collecteur","Demande créée avec statut pending, visible par l'administrateur uniquement pour validation","Réussi"),
    @("T-11","Envoi d'un message dans un fil de discussion sans en etre membre","Insertion refusee par la politique chat_messages_insert_member","Réussi"),
    @("T-12","Chargement de la carte en connexion mobile dégradée (simulee)","Affichage progressif des tuiles, aucun blocage de l'interface","Réussi (avec latence observée, cf. 5.3)"),
    @("T-13","Notification push lors de l'acceptation d'une mission","Le générateur concerné recoit une notification","Partiellement réussi (délai variable selon la plateforme, cf. 5.3)")
)
Caption "Tableau 9 -- Scénarios de test fonctionnels et résultats"

H2 "5.3 Gestion des anomalies et correctifs"
P "Le suivi des anomalies s'est appuye sur les fonctionnalités natives de GitHub (issues et historique de commits), permettant de relier chaque correctif au problème identifié. Deux catégories d'anomalies ont été rencontrees de manière récurrente durant la phase de test."
P "La première concerné des erreurs de politique de sécurité au niveau de la base de données, notamment des cas de recursion infinie détectée dans les politiques RLS (erreur PostgreSQL 42P17) lorsqu'une politique sur la table chat_thread_members verifiait sa propre appartenance par une sous-requete directe sur la meme table. Le correctif a consiste a introduire une fonction dediee en mode SECURITY DEFINER (is_thread_member), contournant ainsi la recursion tout en preservant la logique de contrôlé d'accès."
P "La seconde catégorie porte sur des anomalies liées a la latence réseau en conditions de connectivite dégradée (scénario T-12 et T-13) : chargement lent des tuiles cartographiques et délai variable de reception des notifications push. Ces observations, bien que n'ayant pas empêche la validation fonctionnelle du système, ont été consignees comme axes d'amelioration prioritaires et sont reprises dans les perspectives d'évolution du chapitre 7."
PageBreak

# ============================================================================
# CHAPITRE 6
# ============================================================================
H1 "Chapitre 6 -- Déploiement et maintenance"

H2 "6.1 Pipeline d'intégration et de déploiement continu"
P "Le projet met en oeuvre un pipeline d'intégration continue unique via GitHub Actions (fichier .github/workflows/flutter_ci_cd.yml), organise en deux jobs successifs afin de limiter le cout et le temps d'exécution. Le premier job, analyze_and_test, s'exécuté sur un runner Linux léger a chaque push et a chaque pull request sur la branche main ; le second job, build, plus couteux car exécuté sur un runner macOS (seul environnement permettant de compiler la cible iOS aux cotes des cibles Android et Web), ne se déclenche que lors d'un push effectif sur main, evitant ainsi de mobiliser des minutes macOS a chaque pull request."
Tbl @("Étape","Action réalisée") @(
    @("Checkout du code","Récupération du dépôt GitHub sur le runner d'exécution"),
    @("Analyse statique","Exécution de flutter analyze sur chaque push et pull request, avant tout build couteux"),
    @("Tests automatises","Exécution de flutter test, des lors qu'une suite de tests est présente dans le dépôt"),
    @("Configuration Java 17","Installation de la distribution Zulu, requise par les versions récentes de Gradle/Android"),
    @("Configuration Flutter (canal stable)","Installation du SDK Flutter via l'action subosito/flutter-action, avec mise en cache des dépendances"),
    @("Génération du fichier d'environnement","Écriture d'un fichier JSON ephemere (env/ci.json) a partir des secrets GitHub (SUPABASE_ANON_KEY, MAPBOX_ACCESS_TOKEN, etc.), jamais commite dans le dépôt"),
    @("Build Android","Compilation de l'APK de release avec injection des cles via --dart-define-from-file (flutter build apk --release)"),
    @("Build iOS","Compilation de l'application iOS sans signature (flutter build ios --release --no-codesign)"),
    @("Build Web","Compilation de la version web de production (flutter build web --release)"),
    @("Publication des artefacts","Dépôt des trois builds (APK, application iOS, build web) comme artefacts GitHub, conserves 7 jours")
)
Caption "Tableau 10 -- Étapes du pipeline CI/CD GitHub Actions"
Callout "Figure 7" "Schema du pipeline CI/CD : job analyze_and_test declenche sur push/pull request vers main (runner Linux, rapide et gratuit), suivi -- uniquement sur push vers main -- du job build (runner macOS) qui exécute Build Android / Build iOS / Build Web, jusqu'a la publication des artefacts telechargeables depuis l'onglet Actions de GitHub."

H2 "6.2 Hébergement et infrastructure"
P "L'hébergement de la partie serveur repose entièrement sur l'infrastructure managee de Supabase (projet ixrebfrxhfapndprujvt), qui héberge la base de données PostgreSQL, le service d'authentification, le stockage de fichiers et l'API REST associée. Cette approche dispense le porteur de projet de la gestion directe de serveurs, de systèmes d'exploitation ou de correctifs de sécurité au niveau infrastructure, la responsabilité opérationnelle de ces couches etant assumée par le fournisseur cloud."
P "La distribution de l'application aux utilisateurs finaux differe selon la plateforme : le build web généré par le pipeline CI/CD peut etre publie sur un hébergeur statique (par exemple Firebase Hosting, GitHub Pages ou un hébergement web classique) ; les builds Android (APK) et iOS, en phase de mémoire de fin d'études, sont distribues sous forme d'artefacts telechargeables ou installés manuellement, une publication sur le Google Play Store et l'App Store constituant une perspective naturelle d'évolution (cf. 7.4)."

H2 "6.3 Sécurisation de l'application"
P "La sécurisation de CleanCity repose sur plusieurs mécanismes complémentaires. Au niveau des données, les politiques Row Level Security détaillées au chapitre 3 constituent la première ligne de defense, independamment de toute logique applicative cote client. Au niveau des secrets et clés d'API, les identifiants sensibles -- jeton d'accès Mapbox (MAPBOX_ACCESS_TOKEN), clés Supabase, identifiants OneSignal -- sont injectes au moment de la compilation via le mécanisme --dart-define de Flutter plutot que d'etre codes en dur dans le dépôt source, limitant ainsi le risque de fuite via l'historique Git."
P "Une distinction importante est également maintenue entre la clé publique (anon key) utilisée par le client, dont les privilèges sont entièrement encadres par les politiques RLS, et une éventuelle clé de service (service rôle), réservée a des opérations d'administration cote serveur et qui ne doit en aucun cas etre embarquee dans le code client. Cette séparation garantit qu'une extraction du binaire de l'application ne permettrait pas, a elle seule, de contourner les règles d'accès définies au niveau de la base de données."
P "[Recommandation pour la soutenance : vérifier, avant la remise finale du mémoire, qu'aucune clé secrete ou mot de passe n'apparait en clair dans le dépôt GitHub public, notamment dans l'historique des commits ; le cas echeant, effectuer une rotation des clés concernées.]"

H2 "6.4 Perspectives de maintenance et évolution technique"
P "La maintenabilite de la plateforme s'appuie sur les outils natifs de Supabase : consultation des journaux d'exécution (logs) pour le diagnostic d'incidents, et recours aux recommandations automatiques de sécurité et de performance (advisors) permettant d'identifier, par exemple, des politiques RLS manquantes ou des index sous-optimaux sur une table nouvellement créée. Ces outils constituent une base solide pour assurer, au-dela du cadre du mémoire, une exploitation en conditions réelles de la plateforme."
P "A moyen terme, plusieurs axes de maintenance evolutive se dessinent : mise en place d'une surveillance (monitoring) applicative dediee, automatisation plus poussee des tests d'intégration au sein du pipeline CI/CD existant, et introduction progressive d'un mode de fonctionnement partiellement hors connexion pour les zones a faible connectivite, ces éléments etant développés plus en detail au chapitre 7."
PageBreak

# ============================================================================
# CHAPITRE 7
# ============================================================================
H1 "Chapitre 7 -- Bilan, competences acquises et perspectives"

H2 "7.1 Bilan technique du projet"
P "Le projet CleanCity a permis de mettre en oeuvre, de bout en bout, une application multiplateforme complete reposant sur une architecture Backend-as-a-Service moderne. L'ensemble des spécifications fonctionnelles retenues au chapitre 2 a été implemente et validé par les scénarios de test présentés au chapitre 5 : authentification multi-canal, signalement géolocalisé avec photographie, prise en charge par un collecteur, reception et pesee par un centre de tri, système de points écologiques, demande de retrait Mobile Money, messagerie et espace d'administration."
P "Le choix architectural de s'appuyer sur Supabase et sur PostGIS s'est révélé pertinent au regard des contraintes de temps propres a un mémoire de licence, tout en permettant d'aborder des problematiques avancees de sécurité des données (Row Level Security) et de traitement géospatial, généralement réservées a des architectures plus complexes."

H2 "7.2 Limités identifiées"
P "Plusieurs limités doivent etre reconnues avec objectivite. Le mécanisme de paiement Mobile Money repose, dans l'état actuel du développement, sur une validation manuelle par un administrateur plutot que sur une intégration directe avec une passerelle de paiement d'un opérateur (Orange Money, MTN Mobile Money), ce qui limité le passage a l'échelle du dispositif d'incitation économique. De meme, l'application ne proposé pas encore de mode de fonctionnement véritablement hors connexion, ce qui peut constituer un frein a l'adoption dans les zones les moins bien couvertes par les réseaux mobiles au Cameroun."
P "Sur le plan des tests, la couverture automatisee reste concentree sur la logique des modèles de données ; une extension vers des tests d'intégration automatises (par exemple via des environnements Supabase locaux ephemeres) permettrait de sécuriser davantage les évolutions futures du schema de base de données et des politiques RLS."

H2 "7.3 Competences acquises"
Bullet "Développement mobile et web multiplateforme avec Flutter et Dart, incluant la gestion d'état, la navigation declarative (go_router) et l'intégration de SDK tiers (Mapbox, OneSignal)."
Bullet "Conception et administration d'une base de données relationnelle PostgreSQL, incluant la modélisation de données géospatiales avec PostGIS et l'écriture de fonctions SQL personnalisées (RPC)."
Bullet "Mise en oeuvre concrete de mécanismes de sécurité au niveau des données (Row Level Security), au-dela des seuls contrôlés applicatifs."
Bullet "Pratique du versionnement collaboratif avec Git et GitHub, et mise en place d'un pipeline d'intégration et de déploiement continu (CI/CD) avec GitHub Actions."
Bullet "Élaboration d'une documentation technique structurée (diagrammes UML et C4, dictionnaire de données, cahier des charges) au service de la communication et de la maintenabilite du projet."
Bullet "Démarche de gestion de projet individuelle : planification, priorisation des fonctionnalités au regard d'un délai contraint, et rédaction d'un rapport académique structure."

H2 "7.4 Perspectives d'évolution"
Bullet "Intégrer une véritable passerelle de paiement Mobile Money (API Orange Money / MTN MoMo) afin d'automatiser le versement des gains aux collecteurs sans validation manuelle systématique."
Bullet "Développer un mode de fonctionnement hors connexion (mise en cache locale des signalements et synchronisation differee), particulièrement adapté aux zones peri-urbaines et rurales a connectivite limitée."
Bullet "Enrichir l'espace d'administration d'un tableau de bord statistique (volumes collectes par zone et par période, délais moyens de traitement, taux de valorisation par type de déchet) a destination des autorites municipales partenaires."
Bullet "Étendre la couverture de tests automatises, notamment par des tests d'intégration verifiant systématiquement les politiques Row Level Security a chaque évolution du schema."
Bullet "Envisager une publication officielle sur le Google Play Store et l'App Store, accompagnee d'une stratégie de sensibilisation citoyenne dans les villes camerounaises pilotes."

H2 "Conclusion générale"
P "Ce mémoire a présente la démarche complete de conception, de développement et de déploiement de CleanCity, une application repondant a une problématique concrete et documentée de la gestion des déchets urbains au Cameroun : l'absence d'outil numérique de suivi en temps réel entre citoyens, collecteurs, centres de tri et autorites. En s'appuyant sur une architecture Flutter et Supabase associant PostgreSQL, PostGIS et des politiques de sécurité Row Level Security, le projet démontre qu'une équipe de taille reduite, dans le cadre temporel d'une licence, peut mettre en oeuvre une plateforme fonctionnelle, sécurisée et déployable sur plusieurs cibles."
P "Au-dela de l'aspect technique, ce travail a constitué une occasion de mobiliser et de consolider un ensemble de competences d'ingenierie logicielle -- de l'analyse des besoins a la mise en production -- tout en apportant une réponse concrete, meme partielle, a un enjeu de salubrite publique dont l'importance pour le développement urbain durable du Cameroun n'est plus a démontrer. Les perspectives d'évolution identifiées, notamment l'intégration réelle du paiement mobile et le fonctionnement hors connexion, tracent une feuille de route claire pour la poursuite éventuelle de ce projet au-dela du cadre académique."
PageBreak

# ============================================================================
# BIBLIOGRAPHIE
# ============================================================================
H1 "Bibliographie"
P "[Liste indicative a compléter et a mettre en forme selon la norme bibliographique exigee par l'établissement (APA, IEEE, etc.), avec les dates de consultation effectives.]"
Bullet "Supabase Inc., Documentation officielle Supabase, https://supabase.com/docs"
Bullet "Google LLC, Documentation officielle Flutter, https://docs.flutter.dev"
Bullet "Dart Team, Documentation officielle du langage Dart, https://dart.dev/guides"
Bullet "PostGIS Project Steering Committee, Documentation PostGIS, https://postgis.net/documentation/"
Bullet "The PostgreSQL Global Development Group, Documentation PostgreSQL, https://www.postgresql.org/docs/"
Bullet "Mapbox Inc., Documentation Mapbox (Static Tiles API), https://docs.mapbox.com"
Bullet "GitHub Inc., Documentation GitHub Actions, https://docs.github.com/actions"
Bullet "OWASP Foundation, OWASP Top Ten, https://owasp.org/www-project-top-ten/"
Bullet "Banque mondiale, What a Waste 2.0 -- A Global Snapshot of Solid Waste Management to 2050, Washington D.C."
Bullet "ONU-Habitat, World Cities Report (edition consultee a préciser)"
Bullet "Ministere de l'Environnement, de la Protection de la Nature et du Développement Durable (MINEPDED), Cameroun -- documents et rapports sectoriels (a référencer selon les sources effectivement consultees)"
PageBreak

# ============================================================================
# ANNEXES
# ============================================================================
H1 "Annexes"
H2 "Annexe A -- Extrait du schema de base de données (schema.sql)"
P "L'intégralité du schema SQL (extensions, types énumérés, tables, index, fonctions, politiques RLS et configuration du stockage) est disponible dans le fichier lib/supabase/schema.sql du dépôt source du projet. Un extrait relatif a la table waste_requests est reproduit ci-dessous a titre illustratif :"
Set-Sty "Normal" "Normal"
$sel.Font.Name = "Consolas"; $sel.Font.Size = 9; $sel.ParagraphFormat.Alignment = 0
$sel.TypeText("create table public.waste_requests (")
$sel.TypeParagraph()
$sel.TypeText("  id uuid primary key default gen_random_uuid(),")
$sel.TypeParagraph()
$sel.TypeText("  generator_id uuid not null références public.users (id),")
$sel.TypeParagraph()
$sel.TypeText("  waste_type public.waste_type not null default 'mixed',")
$sel.TypeParagraph()
$sel.TypeText("  status public.waste_status not null default 'pending',")
$sel.TypeParagraph()
$sel.TypeText("  ...")
$sel.TypeParagraph()
$sel.TypeText(");")
$sel.TypeParagraph()
$sel.Font.Name = "Calibri"; $sel.Font.Size = 11; $sel.ParagraphFormat.Alignment = 3
Blank

H2 "Annexe B -- Extrait du pipeline CI/CD (flutter_ci_cd.yml)"
Set-Sty "Normal" "Normal"
$sel.Font.Name = "Consolas"; $sel.Font.Size = 9; $sel.ParagraphFormat.Alignment = 0
$sel.TypeText("on:")
$sel.TypeParagraph()
$sel.TypeText("  push: { branches: [main] }")
$sel.TypeParagraph()
$sel.TypeText("  pull_request: { branches: [main] }")
$sel.TypeParagraph()
$sel.TypeText("jobs:")
$sel.TypeParagraph()
$sel.TypeText("  build_and_upload:")
$sel.TypeParagraph()
$sel.TypeText("    runs-on: macos-latest")
$sel.TypeParagraph()
$sel.TypeText("    steps: [checkout, setup-java-17, setup-flutter, pub-get,")
$sel.TypeParagraph()
$sel.TypeText("            build-apk, build-ios, build-web, upload-artifacts]")
$sel.TypeParagraph()
$sel.Font.Name = "Calibri"; $sel.Font.Size = 11; $sel.ParagraphFormat.Alignment = 3
Blank

H2 "Annexe C -- Captures d'écran"
Callout "Figure A" "Écran d'authentification / sélection du rôle (auth_screens.dart), a inserer depuis l'application."
Callout "Figure B" "Tableau de bord générateur avec liste des signalements et carte associée, a inserer depuis l'application."
Callout "Figure C" "Écran de reception et de pesee cote centre de tri (center_screens.dart), a inserer depuis l'application."
Callout "Figure D" "Espace d'administration (admin_screens.dart) : gestion des utilisateurs et des demandes de retrait, a inserer depuis l'application."

# ============================================================================
# FINALISATION DU DOCUMENT
# ============================================================================
$doc.Repaginate()
$doc.Fields.Update()
if ($doc.TablesOfContents.Count -gt 0) {
    $doc.TablesOfContents.Item(1).Update()
}

$doc.SaveAs2($OutputDocPath, 16)
$doc.Close()
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null

Write-Output "DONE: $OutputDocPath"




