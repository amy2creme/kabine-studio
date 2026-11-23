-- Kabine Studio : installation de la base (à coller une seule fois dans Supabase > SQL Editor > Run)

-- ===== Membres autorisés =====
create table if not exists public.members (
  email text primary key,
  name text not null,
  color text,
  avatar_path text
);

-- Les personnes qui ont accès à l'appli (adresses en minuscules)
insert into public.members (email, name, color) values
  (lower('amy2creme@gmail.com'), 'Amy', '#8C7B6C'),
  (lower('kayliah.kebe@gmail.com'), 'Kayliah', '#1C1A18')
on conflict (email) do update set name = excluded.name, color = excluded.color;

-- ===== Données de l'appli =====
create table if not exists public.docs (
  collection text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by text,
  primary key (collection, id)
);
alter table public.docs replica identity full;

create or replace function public.touch_docs() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := lower(coalesce(auth.jwt()->>'email', new.updated_by)); return new; end $$;
drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before insert or update on public.docs for each row execute function public.touch_docs();

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members m where lower(m.email) = lower(auth.jwt()->>'email'));
$$;

alter table public.members enable row level security;
alter table public.docs enable row level security;

drop policy if exists "membres lisent les membres" on public.members;
create policy "membres lisent les membres" on public.members for select to authenticated using (public.is_member());
drop policy if exists "chacune modifie son profil" on public.members;
create policy "chacune modifie son profil" on public.members for update to authenticated
  using (lower(email) = lower(auth.jwt()->>'email')) with check (lower(email) = lower(auth.jwt()->>'email'));

drop policy if exists "membres gerent les donnees" on public.docs;
create policy "membres gerent les donnees" on public.docs for all to authenticated
  using (public.is_member()) with check (public.is_member());

-- Accès API (seuls les membres passent les règles ci-dessus)
grant usage on schema public to authenticated;
grant select, update on public.members to authenticated;
grant select, insert, update, delete on public.docs to authenticated;
grant execute on function public.is_member() to authenticated;

-- Temps réel (les modifications de l'une apparaissent chez l'autre)
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- ===== Fichiers (photos, vidéos, contrats) : privés =====
insert into storage.buckets (id, name, public, file_size_limit)
values ('assets', 'assets', false, 52428800)
on conflict (id) do nothing;

drop policy if exists "membres lisent les fichiers" on storage.objects;
create policy "membres lisent les fichiers" on storage.objects for select to authenticated using (bucket_id = 'assets' and public.is_member());
drop policy if exists "membres ajoutent des fichiers" on storage.objects;
create policy "membres ajoutent des fichiers" on storage.objects for insert to authenticated with check (bucket_id = 'assets' and public.is_member());
drop policy if exists "membres modifient les fichiers" on storage.objects;
create policy "membres modifient les fichiers" on storage.objects for update to authenticated using (bucket_id = 'assets' and public.is_member());
drop policy if exists "membres suppriment les fichiers" on storage.objects;
create policy "membres suppriment les fichiers" on storage.objects for delete to authenticated using (bucket_id = 'assets' and public.is_member());

-- ===== Données reprises de l'ancienne appli =====
insert into public.docs (collection,id,data) values
('tasks','t01','{"created": 1, "done": false, "text": "Seller Center : relier @kabinecare à la boutique TikTok (compte officiel ou marketing)"}'::jsonb),
('tasks','t02','{"created": 2, "done": false, "text": "Envoyer les messages aux 12 influenceuses (vérifier d''abord les vues des Reels sponsorisés)"}'::jsonb),
('tasks','t03','{"created": 3, "done": false, "text": "Fiche patchs TikTok Shop : remettre « Chiens et Chats »"}'::jsonb),
('tasks','t04','{"created": 4, "done": false, "text": "Shopify : nouvelle description des patchs, poids 80 g et références (SKU)"}'::jsonb),
('tasks','t05','{"created": 5, "done": false, "text": "Vérifier qui paie la livraison gratuite de la Routine sur TikTok Shop"}'::jsonb),
('tasks','t06','{"created": 6, "done": false, "text": "Black Friday : créer l''offre baume (2 achetés = le 3e offert) sur Shopify + visuels"}'::jsonb),
('tasks','t08','{"created": 8, "done": false, "text": "Décider : recharges pour la mousse ? (question d''une cliente)"}'::jsonb),
('tasks','t09','{"created": 9, "done": false, "text": "Sécurité @kabinecare : déconnecter les autres appareils et changer le mot de passe"}'::jsonb),
('tasks','t10','{"created": 10, "done": false, "text": "Metricool : relier Google Drive (pour programmer depuis l''appli)"}'::jsonb),
('tasks','t11','{"created": 11, "done": false, "text": "Vers le 24/11 : vérifier que les abonnés TikTok remontent via Metricool dans l''appli"}'::jsonb),
('tasks','t12','{"created": 12, "done": false, "text": "Préparer la réponse aux commentaires du carrousel perso (le guide promis)"}'::jsonb),
('tasks','t13','{"created": 13, "done": false, "text": "Kayliah : se connecter à Kabine Studio avec son adresse e-mail"}'::jsonb),
('stats','s2026-11-21','{"auto": true, "date": "2026-11-21", "facebook": 39, "instagram": 1494, "perso": 41000, "tiktok": 4378}'::jsonb),
('journal','j01','{"date": "2026-11-20", "cat": "Boutique / produits", "by": "Amy", "title": "Patchs protecteurs mis en vente sur TikTok Shop", "details": "7 tailles (XS à 3XL) à 4,90 € le sachet, poids 80 g, livraison estimée 7,08 € (modèle d''expédition). Fiche validée et en ligne sur le compte boutique @kabinecare.com.", "lesson": "Catégorie à corriger : les patchs sont pour chiens ET chats (voir À faire).", "created": 1}'::jsonb),
('journal','j02','{"date": "2026-11-20", "cat": "Contenu", "by": "Amy", "title": "Guide des tailles des patchs", "details": "Visuel 1200×1200 aux couleurs de la marque + PDF modifiable pour Canva. Mesure horizontale, du premier au dernier coussinet : XS 2,5 cm · S 3,4 · M 3,8 · L 4,5 · XL 5 · XXL 6 · 3XL 7,8.", "lesson": "", "created": 2}'::jsonb),
('journal','j03','{"date": "2026-11-20", "cat": "Offre / code promo", "by": "Amy", "title": "Code BFLIVE20 créé sur Shopify", "details": "-20 % sur tout le site, pour tous les clients, à partir du 20/11 à 20h. Code annoncé pendant le live.", "lesson": "", "created": 3}'::jsonb),
('journal','j04','{"date": "2026-11-20", "cat": "Live", "by": "Amy", "title": "Premier live TikTok (20h)", "details": "Diaporama sur la TV par recopie d''écran : logo, coffret, ingrédients du baume, avant/après, avis de Tm Ngling, vidéo des patchs + guide des tailles, vidéos de clientes. Bandeau fixe : -20 % pendant le live, BFLIVE20, kabinecare.com.", "lesson": "0 commande pendant le live. L''effet miroir de TikTok inversait le texte des visuels : vérifier que le code est lisible pour les spectateurs, ou désactiver « Miroir ».", "created": 4}'::jsonb),
('journal','j05','{"date": "2026-11-21", "cat": "Offre / code promo", "by": "Amy", "title": "BFLIVE20 prolongé jusqu''au 21/11 à minuit", "details": "Fin initiale le 20/11 à 22h, prolongée sur Shopify jusqu''au 21/11 23h59.", "lesson": "Ne plus prolonger une offre, surtout avant Black Friday : une date de fin doit rester ferme pour rester crédible.", "created": 5}'::jsonb),
('journal','j06','{"date": "2026-11-21", "cat": "Réseaux & comptes", "by": "Amy", "title": "Ancien compte kabsfamilly transformé en @kabinecare", "details": "4 378 abonnés. Anciennes vidéos passées en privé, logo, bio « Soin des pattes de chien et chat · Nettoyer · Hydrater · Protéger », lien kabinecare.com cliquable. Compte personnel (41K) gardé pour les lives et l''inspiration. Le compte boutique officiel reste @kabinecare.com (32 abonnés).", "lesson": "Changement de nom TikTok possible une fois tous les 30 jours.", "created": 6}'::jsonb),
('journal','j07','{"date": "2026-11-21", "cat": "Contenu", "by": "Amy", "title": "Carrousel perso « 4 choses que j''ai lâchées »", "details": "7 slides 1080×1350 avec tes photos, appel à commenter pour recevoir un guide.", "lesson": "", "created": 7}'::jsonb),
('journal','j08','{"date": "2026-11-21", "cat": "Contenu", "by": "Amy", "title": "Script de voix off (1 min 30 à 2 min)", "details": "Message « si tu n''aimes pas, désabonne-toi » + partie plus philosophique, à partir de ton texte.", "lesson": "", "created": 8}'::jsonb),
('journal','j09','{"date": "2026-11-21", "cat": "Partenariat", "by": "Amy", "title": "Sélection de 12 influenceuses + messages rédigés", "details": "Fiches ajoutées dans Partenariats (statut « À contacter », commission 15 %). Messages prêts, pas encore envoyés.", "lesson": "", "created": 9}'::jsonb),
('journal','j10','{"date": "2026-11-21", "cat": "Outils", "by": "Amy", "title": "Application Kabine Studio créée (version Claude)", "details": "Tableau de bord (ventes Shopify), publications, aperçu du feed, partenariats et contrats, tâches.", "lesson": "", "created": 10}'::jsonb),
('journal','j11','{"date": "2026-11-21", "cat": "Outils", "by": "Amy", "title": "Metricool connecté (Instagram, Facebook, TikTok)", "details": "Instagram @kabinecare relié à la page Facebook Kabine Care, TikTok @kabinecare.", "lesson": "Pour programmer depuis l''appli, les médias doivent être dans Google Drive relié à Metricool.", "created": 11}'::jsonb),
('journal','j12','{"date": "2026-11-21", "cat": "Outils", "by": "Amy", "title": "Windsor.ai : compte publicitaire Meta relié", "details": "Compte Meta Ads « bigout ». Après l''essai, le plan gratuit ne permet qu''une source et un compte (plan Basique 16 €/mois pour 3 sources).", "lesson": "", "created": 12}'::jsonb),
('journal','j13','{"date": "2026-11-22", "cat": "Outils", "by": "Amy", "title": "Appli Kabine Studio (version Claude) repassée en privé", "details": "Accès : uniquement les personnes invitées. Ajout de l''onglet Historique et des alertes anti-doublon.", "lesson": "", "created": 13}'::jsonb),
('journal','j14','{"date": "2026-11-23", "cat": "Boutique / produits", "by": "Amy", "title": "TikTok Shop : période probatoire identifiée", "details": "Compte officiel @kabinecare.com (personnel, lié le 16/08/2026). Ajout d''un compte marketing bloqué tant que la boutique est en période probatoire. Programme d''essai : 5 commandes/jour max, 5/20 produits.", "lesson": "Ne pas dissocier @kabinecare.com : un nouveau compte officiel devrait être un compte Organisation (irréversible, musique limitée). Sortir de la période probatoire = valider les objectifs du programme d''essai (commandes TikTok Shop).", "created": 14}'::jsonb),
('journal','j15','{"date": "2026-11-23", "cat": "Outils", "by": "Amy", "title": "Kabine Studio : lancement de l''appli officielle", "details": "Code sur GitHub (amy2creme/kabine-studio), base de données Supabase, mise en ligne Netlify, connexion par e-mail ou Google réservée à Amy et Kayliah.", "lesson": "", "created": 15}'::jsonb),
('partners','damon.the.eurasier','{"name": "damon.the.eurasier", "handle": "damon.the.eurasier", "animal": "Eurasier (Damon)", "notes": "13,3k abonnés.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','falcolebergerallemand','{"name": "falcolebergerallemand", "handle": "falcolebergerallemand", "animal": "Berger allemand (Falco)", "notes": "9 921 abonnés.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','ifyoulivewithus','{"name": "ifyoulivewithus", "handle": "ifyoulivewithus", "animal": "Kelpie australien", "notes": "12,4k abonnés.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','marcelthechocolab','{"name": "marcelthechocolab", "handle": "marcelthechocolab", "animal": "Labrador chocolat (Marcel)", "notes": "9 966 abonnés.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','nouba.family','{"name": "nouba.family", "handle": "nouba.family", "animal": "À vérifier (Nouba)", "notes": "14k abonnés. Race à vérifier.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','ourkcya','{"name": "ourkcya", "handle": "ourkcya", "animal": "Malinois", "notes": "3 430 abonnés. Reels ~800-1 100 vues (un à 150k).", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','pac_o_kinai','{"name": "pac_o_kinai", "handle": "pac_o_kinai", "animal": "Samoyède et golden", "notes": "16,4k abonnés. Collabs chat/chien.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','pimstheaussie','{"name": "pimstheaussie", "handle": "pimstheaussie", "animal": "Berger australien", "notes": "11,8k abonnés. Collabs dogchef ≈ 4 000 vues.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','rox_et_rio64','{"name": "rox_et_rio64", "handle": "rox_et_rio64", "animal": "Shiba et beauceron (Rox et Rio)", "notes": "12,9k abonnés. Deux chiens : proposer une Routine pour les deux.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','samskyhezia','{"name": "samskyhezia", "handle": "samskyhezia", "animal": "Samsky (samoyède × husky)", "notes": "21,9k abonnés.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','shibakita_story','{"name": "shibakita_story", "handle": "shibakita_story", "animal": "Shiba (Kita)", "notes": "11k abonnés. Lui demander de parler dans la vidéo.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('partners','unboodenous','{"name": "unboodenous", "handle": "unboodenous", "animal": "Staffy", "notes": "4 921 abonnés.", "status": "À contacter", "type": "Influenceuse", "commission": 15, "code": "", "date": "", "contract": null, "contractName": ""}'::jsonb),
('strategy','st01','{"title": "Black Friday : offre baume 2 achetés = 1 offert", "type": "Offre / promo", "status": "À lancer", "start": "2026-11-27", "end": "2026-11-30", "owner": "Amy", "details": "Créer l''offre sur Shopify, visuels, annonce sur @kabinecare. Date de fin ferme, pas de prolongation.", "created": 1}'::jsonb),
('strategy','st02','{"title": "Sortir de la période probatoire TikTok Shop", "type": "Objectif", "status": "En cours", "owner": "Amy", "unit": "commandes TikTok Shop", "current": 1, "details": "Vérifier les objectifs du Programme d''essai dans le Seller Center (accueil). Leviers : lives vendeurs sur @kabinecare.com avec produits épinglés, affiliation avec les influenceuses.", "created": 2}'::jsonb),
('strategy','st03','{"title": "Lives vendeurs sur @kabinecare.com, annoncés par @kabinecare", "type": "Plan d’action", "status": "À lancer", "owner": "Amy", "details": "Produits épinglés + vente flash live. Annoncer le live la veille et le jour même sur @kabinecare (4 378 abonnés). Régularité plutôt que perfection.", "created": 3}'::jsonb),
('strategy','st04','{"title": "Relier @kabinecare en compte marketing", "type": "Objectif", "status": "Idée", "owner": "Amy", "details": "Possible dès la fin de la période probatoire : Paramètres › Comptes associés TikTok › Comptes marketing.", "created": 4}'::jsonb)
on conflict (collection,id) do nothing;
