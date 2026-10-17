// k6/lib/data.js
// Test data helpers shared by the scenarios

import { SharedArray } from 'k6/data';

// The user pool mirrors what seed_test_data.py created. The seeder writes
// USER_PREFIX, USER_COUNT and TEST_PASSWORD into .env.test; defaults match
// the seeder defaults.
const userPrefix = __ENV.USER_PREFIX || 'perf-user-';
const userCount = Number(__ENV.USER_COUNT) || 50;
const userPassword = __ENV.TEST_PASSWORD || 'Perf-User-Pass-2026!';
const emailPrefix = __ENV.USER_EMAIL_PREFIX || 'perf';
const emailDomain = __ENV.USER_EMAIL_DOMAIN || 'test.local';

// SharedArray ensures data is loaded once and shared across VUs
export const users = new SharedArray('users', function () {
  const userList = [];
  for (let i = 1; i <= userCount; i++) {
    const paddedNum = String(i).padStart(3, '0');
    userList.push({
      username: `${userPrefix}${paddedNum}`,
      password: userPassword,
      email: `${emailPrefix}${paddedNum}@${emailDomain}`,
    });
  }
  return userList;
});

/**
 * Get a random user from the test data
 * @returns {object} - Random user with username, password, email
 */
export function getRandomUser() {
  return users[Math.floor(Math.random() * users.length)];
}

/**
 * Get user by index (for deterministic selection per VU)
 * @param {number} index - User index
 * @returns {object} - User at given index (wraps around if index > length)
 */
export function getUserByIndex(index) {
  return users[index % users.length];
}
