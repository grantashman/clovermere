import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ACTIVITY_DEFINITIONS,
  addItem,
  advanceToNextDay,
  completeRequest,
  createDailyState,
  cropStageForGrowth,
  inventoryQuantity,
  performActivity,
  recordVillagerTalk,
  removeItem,
  RECIPES,
  REQUEST_CATALOG,
  seasonForDay,
  weatherForDay
} from '../src/daily-loop.js';

function state(overrides = {}) {
  return {
    clock: 680,
    day: 3,
    energy: 100,
    maxEnergy: 100,
    coins: 12,
    inventory: { seed_packet: 1 },
    garden: { planted: false, watered: false, ready: false },
    village: { landscape: 'heath' },
    ...overrides
  };
}

test('daily state starts with energy, coins, one seed, and an empty garden', () => {
  assert.deepEqual(createDailyState(), {
    energy: 100,
    maxEnergy: 100,
    coins: 12,
    inventory: { seed_packet: 1 },
    garden: { planted: false, watered: false, ready: false, crop: null, stage: 'empty', growthDays: 0 },
    season: 'Late Summer',
    weather: 'clear',
    weatherSeed: 93,
    onboarding: { garden: false, outing: false, villager: false, rest: false },
    relationships: { pim: 0, wren: 0, cedar: 0, mossy: 0, daisy: 0 },
    request: REQUEST_CATALOG[0]
  });
});

test('weather and season are deterministic for a day and landscape', () => {
  assert.equal(seasonForDay(3), 'Late Summer');
  assert.deepEqual(weatherForDay(8, 'river'), weatherForDay(8, 'river'));
  assert.notEqual(weatherForDay(8, 'river').weather, weatherForDay(9, 'river').weather);
  assert.ok(['clear', 'mist', 'rain', 'golden-wind'].includes(weatherForDay(8, 'river').weather));
});

test('inventory stacks items and refuses removal beyond the held quantity', () => {
  const inventory = addItem({}, 'moonberry', 2);
  const stacked = addItem(inventory, 'moonberry', 3);
  assert.deepEqual(stacked, { moonberry: 5 });
  assert.deepEqual(removeItem(stacked, 'moonberry', 2), { moonberry: 3 });
  assert.equal(removeItem(stacked, 'moonberry', 6), null);
  assert.equal(inventoryQuantity(inventory, 'moonberry'), 2);
});

test('garden activity plants and waters a seed while spending energy and time', () => {
  const result = performActivity(state(), 'garden');
  assert.equal(result.ok, true);
  assert.equal(result.state.energy, 92);
  assert.equal(result.state.clock, 690);
  assert.deepEqual(result.state.inventory, {});
  assert.deepEqual(result.state.garden, { planted: true, watered: true, ready: false, crop: 'moonberry', stage: 'sprout', growthDays: 0 });
  assert.match(result.message, /plant/i);
});

test('watering a planted crop once per day is idempotent and harvest follows staged growth', () => {
  const planted = performActivity(state(), 'garden');
  const wateredAgain = performActivity(planted.state, 'garden');
  assert.equal(wateredAgain.ok, false);
  assert.equal(wateredAgain.state.energy, planted.state.energy);

  const leafDay = advanceToNextDay(planted.state);
  assert.equal(leafDay.day, 4);
  assert.equal(leafDay.clock, 360);
  assert.equal(leafDay.energy, 100);
  assert.deepEqual(leafDay.garden, { planted: true, watered: false, ready: false, crop: 'moonberry', stage: 'leaf', growthDays: 1 });
  assert.equal(leafDay.season, seasonForDay(4));
  assert.equal(leafDay.weather, weatherForDay(4, 'heath').weather);

  const flowerDay = advanceToNextDay({ ...leafDay, garden: { ...leafDay.garden, watered: true } });
  assert.equal(flowerDay.garden.stage, 'flowering');
  const readyDay = advanceToNextDay({ ...flowerDay, garden: { ...flowerDay.garden, watered: true } });
  assert.equal(readyDay.garden.stage, 'ready');
  const harvest = performActivity(readyDay, 'garden');
  assert.equal(harvest.ok, true);
  assert.equal(inventoryQuantity(harvest.state.inventory, 'moonberry'), 3);
  assert.deepEqual(harvest.state.garden, { planted: false, watered: false, ready: false, crop: null, stage: 'empty', growthDays: 0 });
});

test('pond activity gives a fish and market activity buys a seed packet', () => {
  const fished = performActivity(state(), 'fish');
  assert.equal(fished.ok, true);
  assert.equal(inventoryQuantity(fished.state.inventory, 'silver_fish'), 1);
  assert.equal(fished.state.energy, 88);
  assert.equal(fished.state.clock, 700);

  const bought = performActivity(state(), 'market');
  assert.equal(bought.ok, true);
  assert.equal(bought.state.coins, 9);
  assert.equal(inventoryQuantity(bought.state.inventory, 'seed_packet'), 2);
});

test('activities fail without energy or currency and leave state unchanged', () => {
  const tired = performActivity(state({ energy: 5 }), 'fish');
  assert.equal(tired.ok, false);
  assert.equal(tired.state.energy, 5);
  assert.match(tired.message, /energy/i);

  const poor = performActivity(state({ coins: 1 }), 'market');
  assert.equal(poor.ok, false);
  assert.equal(poor.state.coins, 1);
  assert.match(poor.message, /coin/i);
});

test('rest preserves a ready crop until it is harvested', () => {
  const nextDay = advanceToNextDay(state({ garden: { planted: true, watered: false, ready: true, crop: 'moonberry', stage: 'ready', growthDays: 3 } }));
  assert.equal(nextDay.garden.stage, 'ready');
  assert.equal(nextDay.garden.ready, true);
});

test('rest activity advances the day and restores energy through the shared activity interface', () => {
  const result = performActivity(state({ energy: 20, garden: { planted: true, watered: true, ready: false, crop: 'moonberry', stage: 'sprout', growthDays: 0 } }), 'rest');
  assert.equal(result.ok, true);
  assert.equal(result.state.day, 4);
  assert.equal(result.state.clock, 360);
  assert.equal(result.state.energy, 100);
  assert.equal(result.state.garden.stage, 'leaf');
  assert.equal(ACTIVITY_DEFINITIONS.rest.minutes, 0);
});

test('cook turns a berry and fish into one pondside stew', () => {
  const result = performActivity(state({ energy: 60, inventory: { moonberry: 1, silver_fish: 1 } }), 'cook');
  assert.equal(result.ok, true);
  assert.equal(result.state.energy, 56);
  assert.equal(result.state.clock, 710);
  assert.deepEqual(result.state.inventory, { pondside_stew: 1 });
  assert.equal(RECIPES.pondside_stew.result, 'pondside_stew');
});

test('cook fails without ingredients and does not spend energy or time', () => {
  const result = performActivity(state({ inventory: { moonberry: 1 } }), 'cook');
  assert.equal(result.ok, false);
  assert.equal(result.state.energy, 100);
  assert.equal(result.state.clock, 680);
  assert.deepEqual(result.state.inventory, { moonberry: 1 });
  assert.match(result.message, /fish/i);
});

test('eat consumes one stew and caps restored energy at max energy', () => {
  const result = performActivity(state({ energy: 82, inventory: { pondside_stew: 1 } }), 'eat');
  assert.equal(result.ok, true);
  assert.equal(result.state.energy, 100);
  assert.equal(result.state.clock, 685);
  assert.deepEqual(result.state.inventory, {});
});

test('crop stages advance only when watered and use a stable growth table', () => {
  assert.equal(cropStageForGrowth(0), 'sprout');
  assert.equal(cropStageForGrowth(1), 'leaf');
  assert.equal(cropStageForGrowth(2), 'flowering');
  assert.equal(cropStageForGrowth(3), 'ready');
  const dry = advanceToNextDay(state({ garden: { planted: true, watered: false, ready: false, crop: 'moonberry', stage: 'sprout', growthDays: 0 } }));
  assert.equal(dry.garden.growthDays, 0);
  assert.equal(dry.garden.stage, 'sprout');
});

test('talking to a villager increases their relationship without affecting other villagers', () => {
  const result = recordVillagerTalk(state(), 'pim');
  assert.equal(result.ok, true);
  assert.equal(result.state.relationships.pim, 1);
  assert.equal(result.state.relationships.daisy, 0);
  assert.match(result.message, /Pim/i);
});

test('an active villager request consumes the requested item and pays coins plus relationship', () => {
  const requestState = state({ inventory: { silver_fish: 1 }, request: REQUEST_CATALOG[0] });
  const result = completeRequest(requestState, REQUEST_CATALOG[0].id);
  assert.equal(result.ok, true);
  assert.deepEqual(result.state.inventory, {});
  assert.equal(result.state.coins, 18);
  assert.equal(result.state.relationships.pim, 2);
  assert.equal(result.state.request.status, 'complete');
});

test('a request cannot be completed twice or without its requested item', () => {
  const missing = completeRequest(state({ request: REQUEST_CATALOG[0] }), REQUEST_CATALOG[0].id);
  assert.equal(missing.ok, false);
  const complete = completeRequest(state({ inventory: { silver_fish: 1 }, request: REQUEST_CATALOG[0] }), REQUEST_CATALOG[0].id);
  const again = completeRequest(complete.state, REQUEST_CATALOG[0].id);
  assert.equal(again.ok, false);
  assert.match(again.message, /already/i);
});
