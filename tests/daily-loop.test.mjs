import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ACTIVITY_DEFINITIONS,
  addItem,
  advanceToNextDay,
  createDailyState,
  inventoryQuantity,
  performActivity,
  removeItem,
  RECIPES,
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
    day: 3,
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
    garden: { planted: false, watered: false, ready: false },
    season: 'Late Summer',
    weather: 'clear',
    weatherSeed: 93,
    onboarding: { garden: false, outing: false, villager: false, rest: false }
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
  assert.deepEqual(result.state.garden, { planted: true, watered: true, ready: false });
  assert.match(result.message, /plant/i);
});

test('watering a planted crop once per day is idempotent and harvest follows day rollover', () => {
  const planted = performActivity(state({ inventory: {} }), 'garden');
  const wateredAgain = performActivity(planted.state, 'garden');
  assert.equal(wateredAgain.ok, false);
  assert.equal(wateredAgain.state.energy, planted.state.energy);

  const nextDay = advanceToNextDay({ ...planted.state, garden: { planted: true, watered: true, ready: false } });
  assert.equal(nextDay.day, 4);
  assert.equal(nextDay.clock, 360);
  assert.equal(nextDay.energy, 100);
  assert.deepEqual(nextDay.garden, { planted: true, watered: false, ready: true });
  assert.equal(nextDay.season, seasonForDay(4));
  assert.equal(nextDay.weather, weatherForDay(4, 'heath').weather);

  const harvest = performActivity(nextDay, 'garden');
  assert.equal(harvest.ok, true);
  assert.equal(inventoryQuantity(harvest.state.inventory, 'moonberry'), 3);
  assert.deepEqual(harvest.state.garden, { planted: false, watered: false, ready: false });
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
  const nextDay = advanceToNextDay(state({ garden: { planted: true, watered: false, ready: true } }));
  assert.deepEqual(nextDay.garden, { planted: true, watered: false, ready: true });
});

test('rest activity advances the day and restores energy through the shared activity interface', () => {
  const result = performActivity(state({ energy: 20, garden: { planted: true, watered: true, ready: false } }), 'rest');
  assert.equal(result.ok, true);
  assert.equal(result.state.day, 4);
  assert.equal(result.state.clock, 360);
  assert.equal(result.state.energy, 100);
  assert.deepEqual(result.state.garden, { planted: true, watered: false, ready: true });
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
