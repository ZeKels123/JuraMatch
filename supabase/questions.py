# Banque de questions JuraMatch — une par commune, tirée de la description de sa carte.
# Format : (id de la commune, question, bonne réponse, mauvaise réponse 1, mauvaise réponse 2)
# Les mauvaises réponses ont été choisies pour ne PAS correspondre à l'indice selon les descriptions.
# Générer le SQL : python3 supabase/questions.py > supabase/questions.sql
QUESTIONS = [
    ("c-alle", "Quel bourg d'Ajoie est desservi par les Chemins de fer du Jura et entouré de terres agricoles ?", "Alle", "Bure", "Soubey"),
    ("c-basse-allaine", "Quelle commune réunit notamment Buix, Courtemaîche et Montignez ?", "Basse-Allaine", "Haute-Ajoie", "La Baroche"),
    ("c-basse-vendline", "Quelle commune est née de la réunion de Bonfol et Beurnevésin ?", "Basse-Vendline", "Damphreux-Lugnez", "Vendlincourt"),
    ("c-boncourt", "Quel village-frontière du nord de l'Ajoie est relié au rail vers Delle ?", "Boncourt", "Fahy", "Courchavon"),
    ("c-bure", "Quel village agricole de Haute-Ajoie est connu pour sa place d'armes ?", "Bure", "Grandfontaine", "Fahy"),
    ("c-clos-du-doubs", "Quelle commune est organisée autour de Saint-Ursanne, cité médiévale emblématique du Jura ?", "Clos du Doubs", "Soubey", "Saint-Brais"),
    ("c-coeuve", "Quel village ajoulot est connu pour son château et ses lavoirs historiques ?", "Cœuve", "Cornol", "Courchavon"),
    ("c-cornol", "Quel village se trouve proche du Mont Terri ?", "Cornol", "Courgenay", "Alle"),
    ("c-courchavon", "Quel petit village se trouve dans la vallée de l'Allaine, entre Porrentruy et la frontière française ?", "Courchavon", "Courtedoux", "Cœuve"),
    ("c-courgenay", "Quel bourg d'Ajoie, desservi par le rail et l'A16, a une tradition microtechnique liée à l'horlogerie ?", "Courgenay", "Bure", "Damphreux-Lugnez"),
    ("c-courtedoux", "Quelle commune est connue pour les découvertes paléontologiques faites lors des travaux de l'A16 ?", "Courtedoux", "Boncourt", "Bure"),
    ("c-damphreux-lugnez", "Quelle commune issue d'une fusion est connue pour ses zones humides ?", "Damphreux-Lugnez", "Fahy", "Courchavon"),
    ("c-fahy", "Dans quel village de Haute-Ajoie, contre la France, l'agriculture côtoie-t-elle des activités industrielles ?", "Fahy", "Courgenay", "Cœuve"),
    ("c-fontenais", "Quelle commune voisine de Porrentruy comprend notamment Bressaucourt ?", "Fontenais", "Courtedoux", "Courchavon"),
    ("c-grandfontaine", "Quel village de Haute-Ajoie est marqué historiquement par le travail de la pierre ?", "Grandfontaine", "Fahy", "Bure"),
    ("c-haute-ajoie", "Dans quelle commune se trouvent les grottes de Réclère ?", "Haute-Ajoie", "Grandfontaine", "Fahy"),
    ("c-la-baroche", "Quelle commune réunit notamment Asuel, Charmoille, Miécourt et Pleujouse ?", "La Baroche", "Haute-Ajoie", "Basse-Allaine"),
    ("c-porrentruy", "Quelle ville est l'ancienne résidence des princes-évêques ?", "Porrentruy", "Courgenay", "Saignelégier"),
    ("c-vendlincourt", "Quel village d'Ajoie réunit scierie, mécanique de précision et héritage horloger ?", "Vendlincourt", "Alle", "Cœuve"),
    ("c-boecourt", "Quelle commune se trouve proche du nœud routier jurassien ?", "Boécourt", "Courtételle", "Mettembert"),
    ("c-bourrignon", "Quel village se trouve sur l'ancien passage vers Lucelle et les Rangiers ?", "Bourrignon", "Saulcy", "Soyhières"),
    ("c-chatillon", "Quelle petite commune est connue pour son célèbre chêne monumental ?", "Châtillon", "Mettembert", "Movelier"),
    ("c-courchapoix", "Quel village du Val Terbi est traversé par la Scheulte ?", "Courchapoix", "Courroux", "Soyhières"),
    ("c-courrendlin", "Quelle commune est marquée par le passé industriel de Choindez ?", "Courrendlin", "Courroux", "Moutier"),
    ("c-courroux", "Quelle grande commune de l'agglomération de Delémont se trouve dans la vallée de la Birse ?", "Courroux", "Develier", "Courtételle"),
    ("c-courtetelle", "Quelle commune de la vallée de la Sorne se trouve entre Delémont et Haute-Sorne ?", "Courtételle", "Develier", "Rossemaison"),
    ("c-delemont", "Quelle ville est la capitale du canton du Jura ?", "Delémont", "Porrentruy", "Moutier"),
    ("c-develier", "Quelle commune se trouve immédiatement à l'ouest de Delémont, sur le corridor de l'A16 ?", "Develier", "Rossemaison", "Courroux"),
    ("c-ederswiler", "Quelle commune jurassienne est essentiellement germanophone ?", "Ederswiler", "Movelier", "Pleigne"),
    ("c-haute-sorne", "Quelle commune comprend notamment Bassecourt, Courfaivre et Glovelier ?", "Haute-Sorne", "Courtételle", "Val Terbi"),
    ("c-mervelier", "Quel village se trouve au pied des reliefs menant au col du Schelten ?", "Mervelier", "Saulcy", "Bourrignon"),
    ("c-mettembert", "Quelle petite commune est installée sur les hauteurs au nord de Delémont, entre forêts et terres agricoles ?", "Mettembert", "Courtételle", "Rossemaison"),
    ("c-movelier", "Quel village élevé et boisé est proche du plateau de Pleigne ?", "Movelier", "Soyhières", "Develier"),
    ("c-pleigne", "Quelle commune de plateau comprend le secteur de Lucelle ?", "Pleigne", "Saulcy", "Ederswiler"),
    ("c-rossemaison", "Quelle commune est connue dans le Jura pour l'inline hockey ?", "Rossemaison", "Courtételle", "Develier"),
    ("c-saulcy", "Quel village de montagne du district de Delémont se trouve à plus de 900 m d'altitude ?", "Saulcy", "Movelier", "Soyhières"),
    ("c-soyhieres", "Quel village au nord de Delémont se trouve au pied des vestiges de son château ?", "Soyhières", "Châtillon", "Courroux"),
    ("c-val-terbi", "Quelle grande commune est organisée autour de Vicques ?", "Val Terbi", "Courchapoix", "Mervelier"),
    ("c-lajoux", "Quel village élevé des Franches-Montagnes, historiquement agricole, est aussi marqué par l'horlogerie et la mécanique ?", "Lajoux", "Les Enfers", "Soubey"),
    ("c-le-bemont", "Quelle petite commune du haut plateau est desservie par le train rouge des CJ ?", "Le Bémont", "Les Enfers", "Lajoux"),
    ("c-le-noirmont", "Quelle commune est connue pour sa clinique de réadaptation ?", "Le Noirmont", "Saignelégier", "Les Bois"),
    ("c-les-bois", "Quelle commune du haut plateau, proche de la France, est connue pour l'horlogerie et les sports d'hiver ?", "Les Bois", "Les Genevez", "Saint-Brais"),
    ("c-les-breuleux", "Quel bourg industriel des Franches-Montagnes, à plus de 1000 m, est associé à l'horlogerie et aux sports d'hiver ?", "Les Breuleux", "Soubey", "Le Bémont"),
    ("c-les-enfers", "Quelle très petite commune de montagne est caractérisée par ses fermes et ses pâturages boisés ?", "Les Enfers", "Saignelégier", "Le Noirmont"),
    ("c-les-genevez", "Quel village abrite le Musée rural jurassien ?", "Les Genevez", "Lajoux", "Montfaucon"),
    ("c-montfaucon", "Dans quelle commune se trouve la gare de Pré-Petitjean ?", "Montfaucon", "Saint-Brais", "Muriaux"),
    ("c-muriaux", "Quelle commune du plateau possède des vestiges castraux et une halte ferroviaire des CJ ?", "Muriaux", "Les Enfers", "Lajoux"),
    ("c-saignelegier", "Quelle commune accueille le Marché-Concours national de chevaux ?", "Saignelégier", "Le Noirmont", "Montfaucon"),
    ("c-saint-brais", "Quelle commune comprend la halte ferroviaire de Bollement ?", "Saint-Brais", "Soubey", "Muriaux"),
    ("c-soubey", "Quel petit village de la vallée du Doubs possède un ancien moulin hydroélectrique ?", "Soubey", "Saint-Brais", "Les Enfers"),
    ("c-moutier", "Quelle ville est devenue jurassienne en 2026 ?", "Moutier", "Courrendlin", "Delémont"),
]

if __name__ == "__main__":
    def q(s):
        return "'" + s.replace("'", "''") + "'"
    rows = [f"({i + 1}, {q(c)}, {q(t)}, array[{q(a)}, {q(b)}, {q(d)}])" for i, (c, t, a, b, d) in enumerate(QUESTIONS)]
    print("insert into public.jm_questions(id, commune_id, question, choices) values\n" + ",\n".join(rows)
          + "\non conflict (id) do update set commune_id = excluded.commune_id, question = excluded.question, choices = excluded.choices;")
