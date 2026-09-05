/// How a standing world state reads for the party — used only to tint it in
/// the player profile, so "Враг военачальника" and "Уважение фараона" don't
/// look like the same kind of fact.
enum WorldStanding {
  /// The world is inclined to help.
  favorable,

  /// Somebody out there has a reason to make things worse.
  hostile,

  /// A fact with consequences that aren't good or bad on their own — a
  /// carried token, a warning, a bargain whose price hasn't come due.
  neutral,
}

/// Player-facing names for the world flags that represent a *standing state*
/// — something the world will still remember several events from now.
///
/// Same pattern and same reasoning as [allyFlags] (`ally_flags.dart`): the
/// engine has no "reputation" concept, only `WorldState.flags`, and this map
/// is what turns a subset of them into something showable. Allies stay in
/// their own registry because they get their own result card and their own
/// 🔵 influence badge; this one exists purely so the player profile can
/// answer "почему мир так со мной обращается?".
///
/// **Two families are deliberately absent, and that is the important part
/// of this file:**
///
/// 1. *Chain progress* — `dragon_trail_*`, `dragon_lair_known`. Listing
///    those would turn the profile into a quest tracker with a visible
///    checklist, which the design doc's legendary-chain rule explicitly
///    rules out ("никаких сообщений вроде «Начат квест»"). A chain is
///    supposed to feel like rumors the party half-remembers.
/// 2. *Bookkeeping* — `met_*`, `visited_*`, `entered_*`, `read_*`,
///    `in_tavern`. These exist to stop content repeating itself, not to say
///    anything about the party. "Вы заходили в таверну" is not a fact worth
///    a line in a dossier.
///
/// So an unlisted flag renders nowhere, on purpose. Adding a state later is
/// one entry here and nothing else.
const Map<String, ({String name, String description, WorldStanding standing})>
worldStateLabels = {
  // --- Desert ---
  'warlord_respect': (
    name: 'Уважение военачальника',
    description: 'Военачальник пустыни считает вас достойными противниками.',
    standing: WorldStanding.favorable,
  ),
  'warlord_enemy': (
    name: 'Враг военачальника',
    description:
        'Военачальник пустыни не забыл обиду. Его люди встречают вас '
        'недобро.',
    standing: WorldStanding.hostile,
  ),
  'earned_bandit_respect': (
    name: 'Уважение разбойников',
    description:
        'Слово о вас разошлось по лагерям: с вами предпочитают говорить, '
        'а не драться.',
    standing: WorldStanding.favorable,
  ),
  'raided_bandit_camp': (
    name: 'Разорённый лагерь',
    description: 'Разбойники помнят, кто пришёл к ним первым.',
    standing: WorldStanding.hostile,
  ),
  'earned_pharaoh_respect': (
    name: 'Уважение фараона',
    description: 'Древний владыка признал вас гостями, а не расхитителями.',
    standing: WorldStanding.favorable,
  ),
  'found_pharaoh_seal': (
    name: 'Печать фараона',
    description:
        'Печать при вас. Кто-то отдаст за неё многое, кто-то потребует '
        'вернуть.',
    standing: WorldStanding.neutral,
  ),

  // --- The Circle ---
  // `circle_ally` lives in `allyFlags`; this is the other end of the same
  // relationship, and the mirror of `declared_heretic` on the Order's side.
  'circle_enemy': (
    name: 'Круг отвернулся',
    description:
        'Ведьмы вас не простили. В лесу это чувствуется первым, но слухи '
        'расходятся и дальше — травницы и знахарки закрывают перед вами '
        'дверь.',
    standing: WorldStanding.hostile,
  ),

  // --- Forest ---
  'helped_great_witch': (
    name: 'Долг Великой Ведьмы',
    description: 'Ведьма помнит помощь и при случае вмешается на вашей стороне.',
    standing: WorldStanding.favorable,
  ),
  'stole_magic_book': (
    name: 'Украденная книга',
    description:
        'Книга ведьмы у вас, и лес это чувствует. Многое теперь идёт иначе.',
    standing: WorldStanding.hostile,
  ),
  'returned_spellbook': (
    name: 'Книга возвращена',
    description: 'Долг закрыт — лес больше не держит на вас зла за книгу.',
    standing: WorldStanding.favorable,
  ),
  'passed_spirit_trial': (
    name: 'Испытание духа пройдено',
    description: 'Древний Дух Леса счёл вас достойными пройти дальше.',
    standing: WorldStanding.favorable,
  ),
  'made_altar_pact': (
    name: 'Договор с алтарём',
    description:
        'Лесной алтарь получил своё обещание. Такие договоры не забываются.',
    standing: WorldStanding.neutral,
  ),
  'made_a_wish': (
    name: 'Загаданное желание',
    description: 'Желание произнесено. Мир ещё найдёт способ его исполнить.',
    standing: WorldStanding.neutral,
  ),

  // --- Постоянные люди ---
  // Эти флаги помнят не поступок, а человека. Названы так, чтобы в профиле
  // читалось «кто вам должен» и «кто вас не забыл», а не «какой флаг стоит».
  'helped_peddler': (
    name: 'Коробейник помнит добро',
    description:
        'Тот самый коробейник с обочины. Он рассказывает о вас другим '
        'торговцам — и там, куда вы ещё не дошли, вас уже ждут.',
    standing: WorldStanding.favorable,
  ),
  'cheated_peddler': (
    name: 'Коробейник помнит обман',
    description: 'Он узнаёт вас издалека и предупреждает своих.',
    standing: WorldStanding.hostile,
  ),
  'helped_herbwoman': (
    name: 'Травница вам обязана',
    description: 'Женщина с корзиной трав. Её знают и в лесу, и у кладбищенской ограды.',
    standing: WorldStanding.favorable,
  ),
  'cheated_herbwoman': (
    name: 'Травница вас не простила',
    description: 'Взятое без спроса она помнит — и не только она.',
    standing: WorldStanding.hostile,
  ),
  'helped_caravan': (
    name: 'Караванщик вам должен',
    description:
        'Его телеги доходят до самого побережья, и он охотно берёт попутчиков.',
    standing: WorldStanding.favorable,
  ),
  'robbed_caravan': (
    name: 'Караванщик ищет вас',
    description: 'Ваши приметы прибиты к придорожному столбу его рукой.',
    standing: WorldStanding.hostile,
  ),
  'helped_smith': (
    name: 'Кузнец помнит плечо под осью',
    description: 'Он добрался куда хотел — и рассказывает об этом всем.',
    standing: WorldStanding.favorable,
  ),
  'cheated_smith': (
    name: 'Кузнец недосчитался',
    description: 'На вопрос о вашей компании он отвечает честно.',
    standing: WorldStanding.hostile,
  ),
  'helped_cartographer': (
    name: 'Картограф записал ваш путь',
    description:
        'Ваша дорога теперь есть на чужих картах — и встречные знают, что впереди.',
    standing: WorldStanding.favorable,
  ),
  'cheated_cartographer': (
    name: 'Картограф припрятал листы',
    description: 'Карта обрывается там, где начинается нужное.',
    standing: WorldStanding.hostile,
  ),
  'helped_hermit': (
    name: 'Отшельник вас запомнил',
    description: 'Старик спускается с гор редко — но вас узнаёт и внизу.',
    standing: WorldStanding.favorable,
  ),
  'cheated_hermit': (
    name: 'Обещание отшельнику не сдержано',
    description: 'Он не сердится. Он просто ждал.',
    standing: WorldStanding.hostile,
  ),
  'helped_smuggler': (
    name: 'Контрабандист считает вас своими',
    description: 'Он знает берег, знает трактиры и знает, о чём молчать.',
    standing: WorldStanding.favorable,
  ),
  'dodged_taxman': (
    name: 'Сборщик податей вас ищет',
    description:
        'Его книгу переписывают и рассылают. Ваше имя в ней с пометкой.',
    standing: WorldStanding.hostile,
  ),
  'paid_taxman': (
    name: 'Подать уплачена',
    description: 'На заставах вас пропускают без разговоров.',
    standing: WorldStanding.neutral,
  ),

  // --- Coast / sea ---
  // Knowledge, not a relationship — the one entry of its kind so far. It
  // earns a line because it is the answer to "почему нам вдруг попалась эта
  // бухта": the party learned where to look, and the world started offering
  // it.
  'knows_captain_haunt': (
    name: 'Бухта капитана',
    description:
        'Вы знаете, где на этом берегу швартуется корабль с чёрными '
        'парусами. Такое место можно найти и намеренно.',
    standing: WorldStanding.neutral,
  ),
  'cheated_pirate_captain': (
    name: 'Обманутый капитан',
    description: 'Капитан пиратов знает, что его провели, и не прощает такого.',
    standing: WorldStanding.hostile,
  ),

  // --- Mountains / dragon ---
  'dragon_respects_you': (
    name: 'Уважение дракона',
    description:
        'Дракон говорит с вами как с равными — редчайшее из отношений в '
        'этом мире.',
    standing: WorldStanding.favorable,
  ),
  'defeated_dragon': (
    name: 'Дракон побеждён',
    description: 'О таком поют, и вас будут узнавать по этому одному делу.',
    standing: WorldStanding.favorable,
  ),
  'stole_from_dragon': (
    name: 'Обокраденный дракон',
    description: 'Из его логова пропало ваше. Дракон найдёт, у кого спросить.',
    standing: WorldStanding.hostile,
  ),
  'helped_dragon_survivor': (
    name: 'Спасённый выживший',
    description: 'Он не забудет, кто вытащил его из-под пепла.',
    standing: WorldStanding.favorable,
  ),
  'betrayed_dragon_survivor': (
    name: 'Преданный выживший',
    description: 'Он выжил и запомнил, кто оставил его одного.',
    standing: WorldStanding.hostile,
  ),

  // --- Graveyard ---
  'kings_mercy': (
    name: 'Милость Короля мёртвых',
    description: 'Мёртвые получили приказ вас не трогать. Пока.',
    standing: WorldStanding.favorable,
  ),
  'warned_by_gravedigger': (
    name: 'Предупреждение могильщика',
    description: 'Старик рассказал вам то, чего не рассказывает прохожим.',
    standing: WorldStanding.neutral,
  ),

  // --- The Order ---
  // `paladin_ally` lives in `allyFlags` instead, so it gets the 🤝 result
  // card and the 🔵 badge; these two are the other ends of the same
  // relationship.
  'declared_heretic': (
    name: 'Объявлены еретиками',
    description:
        'Орден сказал о вас слово, и оно расходится быстрее людей. '
        'Набожные и осторожные будут держаться от вас подальше.',
    standing: WorldStanding.hostile,
  ),
  'paladin_debt': (
    name: 'Услуга ордена',
    description:
        'За орденом остался долг. Такие долги отдают редко, но отдают '
        'вовремя.',
    standing: WorldStanding.favorable,
  ),

  // --- Tavern / road ---
  'helped_tavern_ghost': (
    name: 'Успокоенный призрак',
    description: 'В заброшенном трактире о вас осталась добрая память.',
    standing: WorldStanding.favorable,
  ),
  'cheated_legendary_cardsharp': (
    name: 'Обманутый шулер',
    description:
        'Легендарный шулер проиграл нечисто и знает это. Такие возвращаются.',
    standing: WorldStanding.hostile,
  ),
  'helped_merchant': (
    name: 'Благодарность торговцев',
    description: 'Торговый люд передаёт друг другу, что с вами можно дело иметь.',
    standing: WorldStanding.favorable,
  ),
  'caught_merchant_scam': (
    name: 'Раскрытый обман',
    description: 'Слух об обмане ушёл к другим торговцам раньше вас.',
    standing: WorldStanding.hostile,
  ),

  // --- The world recognising a legendary origin ---
  // Set inside legendary reveal scenes and, until this registry, read
  // nowhere. Listing them is what gives those one-off moments a lasting
  // trace: the world knows who you turned out to be.
  'dragon_recognized_bloodline': (
    name: 'Дракон узнал кровь',
    description: 'Он понял, кто перед ним, раньше, чем вы назвали себя.',
    standing: WorldStanding.neutral,
  ),
  'spirit_recognized_heir': (
    name: 'Дух узнал наследника',
    description: 'Древний Дух Леса склонился перед тем, кем вы оказались.',
    standing: WorldStanding.neutral,
  ),
  'king_recognized_abyss': (
    name: 'Король узнал бездну',
    description: 'Король мёртвых увидел в одном из вас то, чего боится сам.',
    standing: WorldStanding.neutral,
  ),
  'pharaoh_recognized_chosen': (
    name: 'Фараон узнал избранного',
    description: 'Древний владыка признал в одном из вас своего.',
    standing: WorldStanding.neutral,
  ),
  'captain_recognized_titan': (
    name: 'Капитан узнал титана',
    description: 'Пират видел многое, но такого спутника — впервые.',
    standing: WorldStanding.neutral,
  ),
  'keeper_recognized_archmage': (
    name: 'Хранитель узнал архимага',
    description:
        'Трактирщик увидел, кому досталась последняя капля силы его ордена.',
    standing: WorldStanding.neutral,
  ),
};
