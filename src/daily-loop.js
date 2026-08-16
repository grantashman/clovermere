export const ITEMS = {
  seed_packet: { id: 'seed_packet', name: 'Moonberry seeds', shortName: 'Seeds', stackLimit: 9, value: 3 },
  moonberry: { id: 'moonberry', name: 'Moonberries', shortName: 'Berries', stackLimit: 20, value: 6 },
  silver_fish: { id: 'silver_fish', name: 'Silver fish', shortName: 'Fish', stackLimit: 10, value: 8 }
};

export const ACTIVITY_DEFINITIONS = {
  garden: { id: 'garden', label: 'Tend the garden', minutes: 10, energy: 8 },
  fish: { id: 'fish', label: 'Fish at the pond', minutes: 20, energy: 12 },
  market: { id: 'market', label: 'Buy seeds at the market', minutes: 10, energy: 2, coins: 3 },
  rest: { id: 'rest', label: 'Rest at home', minutes: 0, energy: 0 }
};

const MAX_DAY_MINUTES = 24 * 60;
const STARTING_ENERGY = 100;
const STARTING_COINS = 12;

export function createDailyState() {
  return {
    energy: STARTING_ENERGY,
    maxEnergy: STARTING_ENERGY,
    coins: STARTING_COINS,
    inventory: { seed_packet: 1 },
    garden: { planted: false, watered: false, ready: false }
  };
}

export function normalizeDailyState(source = {}) {
  const defaults = createDailyState();
  const inventory = source.inventory && typeof source.inventory === 'object' ? source.inventory : defaults.inventory;
  const garden = source.garden && typeof source.garden === 'object' ? source.garden : {};
  const maxEnergy = Number.isFinite(source.maxEnergy) && source.maxEnergy > 0 ? source.maxEnergy : defaults.maxEnergy;
  return {
    energy: Number.isFinite(source.energy) ? Math.max(0, Math.min(maxEnergy, source.energy)) : defaults.energy,
    maxEnergy,
    coins: Number.isFinite(source.coins) ? Math.max(0, Math.floor(source.coins)) : defaults.coins,
    inventory: Object.fromEntries(Object.entries(inventory).filter(([, quantity]) => Number(quantity) > 0).map(([id, quantity]) => [id, Math.max(0, Math.floor(Number(quantity)))])),
    garden: {
      planted: Boolean(garden.planted),
      watered: Boolean(garden.watered),
      ready: Boolean(garden.ready)
    }
  };
}

export function inventoryQuantity(inventory = {}, itemId) {
  return Math.max(0, Number(inventory[itemId] ?? 0));
}

export function addItem(inventory = {}, itemId, quantity = 1) {
  if (!ITEMS[itemId] || !Number.isFinite(quantity) || quantity <= 0) return { ...inventory };
  const item = ITEMS[itemId];
  const current = inventoryQuantity(inventory, itemId);
  const next = Math.min(item.stackLimit, current + Math.floor(quantity));
  return { ...inventory, [itemId]: next };
}

export function removeItem(inventory = {}, itemId, quantity = 1) {
  if (!ITEMS[itemId] || !Number.isFinite(quantity) || quantity <= 0 || inventoryQuantity(inventory, itemId) < quantity) return null;
  const next = { ...inventory };
  const remaining = inventoryQuantity(next, itemId) - Math.floor(quantity);
  if (remaining) next[itemId] = remaining;
  else delete next[itemId];
  return next;
}

function advanceClock(clock, minutes) {
  const next = Number(clock ?? 0) + minutes;
  return next >= MAX_DAY_MINUTES ? next - MAX_DAY_MINUTES : next;
}

function cloneDailyState(input) {
  const normalized = normalizeDailyState(input);
  return {
    ...input,
    ...normalized,
    inventory: { ...normalized.inventory },
    garden: { ...normalized.garden }
  };
}

function spend(state, activity) {
  const next = cloneDailyState(state);
  next.energy -= activity.energy ?? 0;
  next.clock = advanceClock(state.clock, activity.minutes ?? 0);
  return next;
}

function fail(state, message) {
  return { ok: false, state: cloneDailyState(state), message };
}

export function advanceToNextDay(input) {
  const next = cloneDailyState(input);
  return {
    ...next,
    day: Number(input.day ?? 1) + 1,
    clock: 6 * 60,
    energy: next.maxEnergy,
    garden: {
      planted: next.garden.planted,
      watered: false,
      ready: next.garden.ready || (next.garden.planted && next.garden.watered)
    }
  };
}

export function performActivity(input, activityId) {
  const state = cloneDailyState(input);
  const activity = ACTIVITY_DEFINITIONS[activityId];
  if (!activity) return fail(state, 'That activity is not available here.');
  if (activityId === 'rest') {
    return { ok: true, state: advanceToNextDay(state), message: 'You rest by the hearth. A new morning gathers outside.' };
  }
  if (state.energy < activity.energy) return fail(state, 'You do not have enough energy for that. Rest at home to recover.');
  if (activity.coins && state.coins < activity.coins) return fail(state, 'You need more coins for that purchase.');

  if (activityId === 'garden') {
    if (state.garden.ready) {
      const next = spend(state, { ...activity, energy: 4 });
      next.inventory = addItem(next.inventory, 'moonberry', 3);
      next.garden = { planted: false, watered: false, ready: false };
      return { ok: true, state: next, message: 'You harvest three moonberries and tuck them safely in your satchel.' };
    }
    if (!state.garden.planted) {
      const inventory = removeItem(state.inventory, 'seed_packet', 1);
      if (!inventory) return fail(state, 'You have no moonberry seeds. Visit the market first.');
      const next = spend({ ...state, inventory }, activity);
      next.garden = { planted: true, watered: true, ready: false };
      return { ok: true, state: next, message: 'You plant a moonberry seed and give the little bed a careful drink.' };
    }
    if (state.garden.watered) return fail(state, 'The garden is already watered. Let the moonberries grow.');
    const next = spend(state, activity);
    next.garden.watered = true;
    return { ok: true, state: next, message: 'You water the growing moonberries. Their leaves lift toward the light.' };
  }

  if (activityId === 'fish') {
    const next = spend(state, activity);
    next.inventory = addItem(next.inventory, 'silver_fish', 1);
    return { ok: true, state: next, message: 'A silver fish bites. You land it neatly and add it to your satchel.' };
  }

  if (activityId === 'market') {
    const next = spend(state, activity);
    next.coins -= activity.coins;
    next.inventory = addItem(next.inventory, 'seed_packet', 1);
    return { ok: true, state: next, message: 'You trade three coins for a fresh moonberry seed packet.' };
  }

  return fail(state, 'Nothing happens.');
}
