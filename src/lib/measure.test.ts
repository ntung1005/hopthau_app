// Chạy: npm test (node --test, Node 22 tự bỏ kiểu TypeScript).
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseMillions, vnd, vndShort, foldVietnamese } from './format.ts';
import {
  clampOpenings, door, edges, floorArea, packageTotal, perimeter, planFromJson, planTemplates, planToJson, quoteDiff, room,
  wallSpan,
} from './measure.ts';

test('format', () => {
  assert.equal(vnd(31960000), '31.960.000 đ');
  assert.equal(vnd(-1500), '-1.500 đ');
  assert.equal(vndShort(31960000), '32 triệu');
  assert.equal(vndShort(31940000), '31,9 triệu');
  assert.equal(parseMillions('13,5'), 13500000);
  assert.equal(parseMillions('abc'), null);
  assert.equal(foldVietnamese('Sông Hồng'), 'song hong');
});

test('góc cắt: diện tích, chu vi, đoạn tường', () => {
  const r = room({ id: 'r1', name: 'P', type: 'bedroom', x: 0, y: 0, w: 4, l: 3 });
  assert.equal(floorArea(r), 12);
  assert.equal(perimeter(r), 14);
  r.cuts.push({ corner: 'ne', kind: 'notch', dx: 1, dy: 0.5 });
  assert.equal(floorArea(r), 11.5);
  assert.equal(edges(r).length, 6);
  assert.deepEqual(wallSpan(r, 'n'), [0, 3]);
  r.cuts[0].kind = 'chamfer';
  assert.equal(floorArea(r), 11.75);
});

test('clampOpenings giữ cửa trong đoạn tường còn lại', () => {
  const r = room({ id: 'r1', name: 'P', type: 'other', x: 0, y: 0, w: 2, l: 2, openings: [door('n', 1.8)] });
  clampOpenings(r);
  assert.equal(r.openings[0].offset + r.openings[0].width <= 2 + 1e-9, true);
});

test('JSON khứ hồi giữ nguyên mẫu', () => {
  const p = planTemplates['Căn 2 phòng ngủ (~56 m²)']();
  assert.deepEqual(planToJson(planFromJson(planToJson(p))), planToJson(p));
});

test('quoteDiff và giá gói', () => {
  const d = quoteDiff(
    [{ room: 'A', name: 'Giường', qty: 1 }, { room: 'A', name: 'Tủ', qty: 2 }],
    [{ room: 'A', name: 'Giường', qty: 2, unit_price: 5 }, { room: 'B', name: 'Kệ', qty: 1, unit_price: 1 }],
  );
  assert.deepEqual(d.map((l) => l.tag), ['changed', 'added', 'removed']);
  assert.equal(packageTotal([{ qty: '1.5', unit_price: 1000 }, { id: 'o', qty: 1, unit_price: 9, is_optional: true }], new Set()), 1500);
});
