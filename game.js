"use strict";

const MAP_WIDTH = 44;
const MAP_HEIGHT = 28;
const TILE_SIZE = 32;
const VIEW_WIDTH = 30;
const VIEW_HEIGHT = 20;

const TERRAIN = {
  water: { name: "Agua", color: "#2d628e", accent: "#4d8ec2", food: 1, production: 0, gold: 1, moveCost: 999, defense: 0 },
  grass: { name: "Pradera", color: "#6ca969", accent: "#8fcc7d", food: 2, production: 1, gold: 1, moveCost: 1, defense: 0 },
  plains: { name: "Llanura", color: "#bda969", accent: "#dfca87", food: 1, production: 2, gold: 1, moveCost: 1, defense: 0 },
  forest: { name: "Bosque", color: "#3f7644", accent: "#77b85f", food: 1, production: 2, gold: 0, moveCost: 2, defense: 1 },
  hill: { name: "Colina", color: "#8c7656", accent: "#caa57d", food: 0, production: 2, gold: 2, moveCost: 2, defense: 2 },
};

const UNIT_TYPES = {
  settler: { name: "Colono", hp: 10, attack: 0, moves: 2, vision: 3, cost: 18, symbol: "S" },
  warrior: { name: "Guerrero", hp: 12, attack: 4, moves: 2, vision: 3, cost: 14, symbol: "W" },
  scout: { name: "Explorador", hp: 8, attack: 2, moves: 3, vision: 4, cost: 10, symbol: "E" },
};

const CITY_NAMES = ["Aurora", "Helios", "Argos", "Vesta", "Nova", "Lumen", "Orion", "Atlas", "Delta", "Pax"];

const SPRITES = {
  city: ["....AA....", "...AAAA...", "..AABBAA..", "..AABBAA..", ".CCCCCCCC.", ".CDBBBDDC.", ".CDBBBDDC.", ".CCCCCCCC.", ".D......D.", ".DDDDDDDD."],
  settler: ["...AA...", "..AAAA..", "..ABBA..", "...CC...", "..CDDC..", "..C..C..", ".CC..CC.", ".D....D."],
  warrior: ["...AA...", "..ABBA..", "..ABBA..", "...CC...", "..CDDC..", ".CCEECC.", "..E..E..", ".DD..DD."],
  scout: ["...AA...", "..ABBA..", "...CC...", "..CDDC..", ".CCEECC.", "..E..E..", ".D....D.", "D......D"],
};

class CivGame {
  constructor() {
    this.canvas = document.getElementById("gameCanvas");
    this.ctx = this.canvas.getContext("2d");
    this.ctx.imageSmoothingEnabled = false;

    this.minimapCanvas = document.getElementById("minimapCanvas");
    this.minimapCtx = this.minimapCanvas.getContext("2d");
    this.minimapCtx.imageSmoothingEnabled = false;

    this.ui = {
      turn: document.getElementById("turnStat"),
      activePlayer: document.getElementById("activePlayerStat"),
      gold: document.getElementById("goldStat"),
      science: document.getElementById("scienceStat"),
      cityCount: document.getElementById("cityStat"),
      unitCount: document.getElementById("unitStat"),
      selectionMode: document.getElementById("selectionMode"),
      selectionInfo: document.getElementById("selectionInfo"),
      tileInfo: document.getElementById("tileInfo"),
      hoverCoords: document.getElementById("hoverCoords"),
      eventLog: document.getElementById("eventLog"),
      winnerBanner: document.getElementById("winnerBanner"),
      buttons: {
        endTurn: document.getElementById("endTurnBtn"),
        newGame: document.getElementById("newGameBtn"),
        foundCity: document.getElementById("foundCityBtn"),
        queueWarrior: document.getElementById("queueWarriorBtn"),
        queueScout: document.getElementById("queueScoutBtn"),
        queueSettler: document.getElementById("queueSettlerBtn"),
      },
    };

    this.bindEvents();
    this.newGame();
    window.requestAnimationFrame(() => this.loop());
  }

  bindEvents() {
    this.canvas.addEventListener("click", (event) => this.handleCanvasClick(event));
    this.canvas.addEventListener("mousemove", (event) => this.handleCanvasMove(event));
    this.canvas.addEventListener("mouseleave", () => {
      this.hoverTile = null;
      this.updateTileInfo();
    });
    this.canvas.addEventListener("contextmenu", (event) => event.preventDefault());

    this.ui.buttons.endTurn.addEventListener("click", () => this.endTurn());
    this.ui.buttons.newGame.addEventListener("click", () => this.newGame());
    this.ui.buttons.foundCity.addEventListener("click", () => this.tryFoundCity());
    this.ui.buttons.queueWarrior.addEventListener("click", () => this.queueSelectedCity("warrior"));
    this.ui.buttons.queueScout.addEventListener("click", () => this.queueSelectedCity("scout"));
    this.ui.buttons.queueSettler.addEventListener("click", () => this.queueSelectedCity("settler"));

    window.addEventListener("keydown", (event) => this.handleKeydown(event));
  }

  newGame() {
    this.turn = 1;
    this.currentPlayerIndex = 0;
    this.nextUnitId = 1;
    this.nextCityId = 1;
    this.cityNameIndex = 0;
    this.selectedUnitId = null;
    this.selectedCityId = null;
    this.hoverTile = null;
    this.camera = { x: 0, y: 0 };
    this.messages = [];
    this.winner = null;

    this.map = this.generateMap();
    this.players = this.createPlayers();
    this.setupStartingUnits();
    this.startPlayerTurn(this.currentPlayer);
    this.centerCameraOnPlayer(this.players[0]);

    this.log("Nuevo mundo generado. Funda una ciudad con tu colono.");
    this.log("Selecciona una unidad y haz click en casillas dentro del alcance.");
    this.syncUI();
  }

  get currentPlayer() {
    return this.players[this.currentPlayerIndex];
  }

  createPlayers() {
    return [
      { id: 0, name: "Liga Solar", color: "#f8d36a", dark: "#7f5e21", isHuman: true, gold: 10, science: 0, units: [], cities: [], visible: new Set(), explored: new Set() },
      { id: 1, name: "Pacto Carmesi", color: "#f27768", dark: "#6d2a26", isHuman: false, gold: 10, science: 0, units: [], cities: [], visible: new Set(), explored: new Set() },
    ];
  }

  generateMap() {
    const landMask = [];
    for (let y = 0; y < MAP_HEIGHT; y += 1) {
      const row = [];
      for (let x = 0; x < MAP_WIDTH; x += 1) {
        const edgePenalty = x < 3 || y < 3 || x > MAP_WIDTH - 4 || y > MAP_HEIGHT - 4 ? 0.18 : 0;
        row.push(Math.random() > 0.43 + edgePenalty);
      }
      landMask.push(row);
    }

    for (let pass = 0; pass < 4; pass += 1) {
      const next = [];
      for (let y = 0; y < MAP_HEIGHT; y += 1) {
        const row = [];
        for (let x = 0; x < MAP_WIDTH; x += 1) {
          let count = 0;
          for (let oy = -1; oy <= 1; oy += 1) {
            for (let ox = -1; ox <= 1; ox += 1) {
              if (ox === 0 && oy === 0) {
                continue;
              }
              const nx = x + ox;
              const ny = y + oy;
              if (!this.inBounds(nx, ny) || landMask[ny][nx]) {
                count += 1;
              }
            }
          }
          row.push(count >= 5);
        }
        next.push(row);
      }
      for (let y = 0; y < MAP_HEIGHT; y += 1) {
        for (let x = 0; x < MAP_WIDTH; x += 1) {
          landMask[y][x] = next[y][x];
        }
      }
    }

    const map = [];
    for (let y = 0; y < MAP_HEIGHT; y += 1) {
      const row = [];
      for (let x = 0; x < MAP_WIDTH; x += 1) {
        let terrain = "water";
        if (landMask[y][x]) {
          const roll = Math.random();
          if (roll < 0.34) {
            terrain = "grass";
          } else if (roll < 0.6) {
            terrain = "plains";
          } else if (roll < 0.83) {
            terrain = "forest";
          } else {
            terrain = "hill";
          }
        }
        row.push({ terrain });
      }
      map.push(row);
    }
    return map;
  }

  setupStartingUnits() {
    const starts = this.findStartPositions(2);
    this.players.forEach((player, index) => {
      const [x, y] = starts[index];
      this.createUnit(player.id, "settler", x, y);
      const guardSpot = this.findFreeAdjacent(x, y) || [x, y];
      this.createUnit(player.id, "warrior", guardSpot[0], guardSpot[1]);
      const scoutSpot = this.findFreeAdjacent(x, y) || guardSpot;
      if (!this.getUnitAt(scoutSpot[0], scoutSpot[1])) {
        this.createUnit(player.id, "scout", scoutSpot[0], scoutSpot[1]);
      }
    });
  }

  findStartPositions(count) {
    const starts = [];
    let attempts = 0;
    while (starts.length < count && attempts < 8000) {
      attempts += 1;
      const x = 3 + Math.floor(Math.random() * (MAP_WIDTH - 6));
      const y = 3 + Math.floor(Math.random() * (MAP_HEIGHT - 6));
      const tile = this.getTile(x, y);
      if (!tile || tile.terrain === "water" || tile.terrain === "hill") {
        continue;
      }
      if (starts.some(([sx, sy]) => this.distance(x, y, sx, sy) < 18)) {
        continue;
      }
      starts.push([x, y]);
    }

    if (starts.length < count) {
      for (let y = 3; y < MAP_HEIGHT - 3; y += 1) {
        for (let x = 3; x < MAP_WIDTH - 3; x += 1) {
          const tile = this.getTile(x, y);
          if (!tile || tile.terrain === "water" || tile.terrain === "hill") {
            continue;
          }
          if (starts.some(([sx, sy]) => this.distance(x, y, sx, sy) < 18)) {
            continue;
          }
          starts.push([x, y]);
          if (starts.length === count) {
            return starts;
          }
        }
      }
    }

    while (starts.length < count) {
      let fallback = null;
      for (let y = 1; y < MAP_HEIGHT - 1 && !fallback; y += 1) {
        for (let x = 1; x < MAP_WIDTH - 1; x += 1) {
          const tile = this.getTile(x, y);
          if (!tile || tile.terrain === "water") {
            continue;
          }
          if (starts.some(([sx, sy]) => sx === x && sy === y)) {
            continue;
          }
          fallback = [x, y];
          break;
        }
      }
      starts.push(fallback || [1, 1]);
    }
    return starts;
  }

  startPlayerTurn(player) {
    player.units.forEach((unit) => {
      unit.movesLeft = UNIT_TYPES[unit.type].moves;
    });
    this.refreshVisibility(player);
    this.checkVictory();
    this.syncUI();
  }

  endTurn() {
    if (!this.currentPlayer.isHuman || this.winner) {
      return;
    }

    this.processEndOfTurn(this.currentPlayer);
    this.advanceToNextPlayer();

    while (!this.currentPlayer.isHuman && !this.winner) {
      this.startPlayerTurn(this.currentPlayer);
      this.runAITurn(this.currentPlayer);
      this.processEndOfTurn(this.currentPlayer);
      if (this.winner) {
        break;
      }
      this.advanceToNextPlayer();
    }

    if (!this.winner) {
      this.startPlayerTurn(this.currentPlayer);
      this.log(`Turno ${this.turn}. Actua ${this.currentPlayer.name}.`);
    }
    this.syncUI();
  }

  advanceToNextPlayer() {
    this.currentPlayerIndex = (this.currentPlayerIndex + 1) % this.players.length;
    if (this.currentPlayerIndex === 0) {
      this.turn += 1;
    }
    this.selectedUnitId = null;
    this.selectedCityId = null;
  }

  processEndOfTurn(player) {
    player.cities.forEach((city) => {
      const yields = this.getCityYield(city);
      city.food += yields.food;
      city.production += yields.production;
      player.gold += yields.gold;
      player.science += Math.max(1, Math.floor((yields.food + yields.production) / 2));

      const growthCost = 8 + city.population * 4;
      if (city.food >= growthCost) {
        city.food -= growthCost;
        city.population += 1;
        city.hp = Math.min(city.hp + 2, 18 + city.population * 2);
        if (player.isHuman) {
          this.log(`${city.name} crece a poblacion ${city.population}.`);
        }
      }

      if (city.queue) {
        const unitDef = UNIT_TYPES[city.queue];
        if (city.production >= unitDef.cost) {
          const spawn = this.findFreeAdjacent(city.x, city.y);
          if (spawn) {
            city.production -= unitDef.cost;
            this.createUnit(player.id, city.queue, spawn[0], spawn[1]);
            if (player.isHuman) {
              this.log(`${city.name} completa ${unitDef.name}.`);
            }
            city.queue = null;
          }
        }
      }
    });

    if (!player.isHuman) {
      this.chooseAIProduction(player);
    }

    this.refreshVisibility(player);
    this.checkVictory();
  }

  getCityYield(city) {
    const center = this.getTile(city.x, city.y);
    const worked = this.getWorkedTiles(city);
    const base = {
      food: TERRAIN[center.terrain].food + 1,
      production: TERRAIN[center.terrain].production + 1,
      gold: TERRAIN[center.terrain].gold + 1,
    };

    worked.forEach((tile) => {
      const data = TERRAIN[this.getTile(tile.x, tile.y).terrain];
      base.food += data.food;
      base.production += data.production;
      base.gold += data.gold;
    });
    return base;
  }

  getWorkedTiles(city) {
    const candidates = [];
    for (let oy = -1; oy <= 1; oy += 1) {
      for (let ox = -1; ox <= 1; ox += 1) {
        if (ox === 0 && oy === 0) {
          continue;
        }
        const x = city.x + ox;
        const y = city.y + oy;
        const tile = this.getTile(x, y);
        if (!tile || tile.terrain === "water") {
          continue;
        }
        const data = TERRAIN[tile.terrain];
        candidates.push({ x, y, score: data.food * 2 + data.production * 2 + data.gold });
      }
    }
    candidates.sort((a, b) => b.score - a.score);
    return candidates.slice(0, Math.max(0, city.population - 1));
  }

  chooseAIProduction(player) {
    const settlerCount = player.units.filter((unit) => unit.type === "settler").length;
    player.cities.forEach((city) => {
      if (city.queue) {
        return;
      }
      if (player.cities.length < 2 && settlerCount === 0 && city.population >= 2) {
        city.queue = "settler";
        return;
      }
      city.queue = player.units.length < player.cities.length * 3 ? "warrior" : "scout";
    });
  }

  createUnit(ownerId, type, x, y) {
    const def = UNIT_TYPES[type];
    const owner = this.players[ownerId];
    const unit = { id: this.nextUnitId, ownerId, type, x, y, hp: def.hp, movesLeft: def.moves };
    this.nextUnitId += 1;
    owner.units.push(unit);
    this.refreshVisibility(owner);
    return unit;
  }

  createCity(ownerId, x, y) {
    const owner = this.players[ownerId];
    const city = {
      id: this.nextCityId,
      ownerId,
      name: `${CITY_NAMES[this.cityNameIndex % CITY_NAMES.length]}${Math.floor(this.cityNameIndex / CITY_NAMES.length) + 1}`,
      x,
      y,
      population: 1,
      food: 0,
      production: 0,
      hp: 14,
      queue: "warrior",
    };
    this.cityNameIndex += 1;
    this.nextCityId += 1;
    owner.cities.push(city);
    this.refreshVisibility(owner);
    return city;
  }

  removeUnit(unit) {
    const owner = this.players[unit.ownerId];
    owner.units = owner.units.filter((entry) => entry.id !== unit.id);
    if (this.selectedUnitId === unit.id) {
      this.selectedUnitId = null;
    }
    this.refreshVisibility(owner);
  }

  getTile(x, y) {
    if (!this.inBounds(x, y)) {
      return null;
    }
    return this.map[y][x];
  }

  getUnitAt(x, y) {
    for (const player of this.players) {
      const unit = player.units.find((entry) => entry.x === x && entry.y === y);
      if (unit) {
        return unit;
      }
    }
    return null;
  }

  getCityAt(x, y) {
    for (const player of this.players) {
      const city = player.cities.find((entry) => entry.x === x && entry.y === y);
      if (city) {
        return city;
      }
    }
    return null;
  }

  getSelectedUnit() {
    return this.currentPlayer.units.find((unit) => unit.id === this.selectedUnitId) || null;
  }

  getSelectedCity() {
    return this.currentPlayer.cities.find((city) => city.id === this.selectedCityId) || null;
  }

  canFoundCity(unit) {
    if (!unit || unit.type !== "settler") {
      return false;
    }
    const tile = this.getTile(unit.x, unit.y);
    if (!tile || tile.terrain === "water" || this.getCityAt(unit.x, unit.y)) {
      return false;
    }
    for (const player of this.players) {
      for (const city of player.cities) {
        if (this.distance(unit.x, unit.y, city.x, city.y) < 5) {
          return false;
        }
      }
    }
    return true;
  }

  tryFoundCity() {
    const unit = this.getSelectedUnit();
    if (!unit || !this.currentPlayer.isHuman) {
      return;
    }
    if (!this.canFoundCity(unit)) {
      this.log("No puedes fundar una ciudad en esa casilla.");
      this.syncUI();
      return;
    }
    const city = this.createCity(unit.ownerId, unit.x, unit.y);
    this.removeUnit(unit);
    this.selectedCityId = city.id;
    this.selectedUnitId = null;
    this.log(`Fundaste ${city.name}. La ciudad empieza entrenando un guerrero.`);
    this.checkVictory();
    this.syncUI();
  }

  queueSelectedCity(type) {
    const city = this.getSelectedCity();
    if (!city || !this.currentPlayer.isHuman) {
      return;
    }
    city.queue = type;
    this.log(`${city.name} comienza a entrenar ${UNIT_TYPES[type].name}.`);
    this.syncUI();
  }

  handleCanvasClick(event) {
    if (!this.currentPlayer.isHuman || this.winner) {
      return;
    }

    const tilePos = this.screenToTile(event);
    if (!tilePos) {
      return;
    }
    const { x, y } = tilePos;
    if (!this.isVisibleToPlayer(this.currentPlayer, x, y)) {
      this.log("Solo puedes interactuar con casillas visibles.");
      this.syncUI();
      return;
    }

    const ownUnit = this.currentPlayer.units.find((unit) => unit.x === x && unit.y === y);
    if (ownUnit) {
      this.selectedUnitId = ownUnit.id;
      this.selectedCityId = null;
      this.centerCameraOn(x, y);
      this.syncUI();
      return;
    }

    const ownCity = this.currentPlayer.cities.find((city) => city.x === x && city.y === y);
    if (ownCity) {
      this.selectedCityId = ownCity.id;
      this.selectedUnitId = null;
      this.centerCameraOn(x, y);
      this.syncUI();
      return;
    }

    const unit = this.getSelectedUnit();
    if (unit) {
      this.issueUnitOrder(unit, x, y);
      this.syncUI();
      return;
    }

    this.selectedCityId = null;
    this.selectedUnitId = null;
    this.syncUI();
  }

  handleCanvasMove(event) {
    const tilePos = this.screenToTile(event);
    this.hoverTile = tilePos;
    this.updateTileInfo();
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      this.endTurn();
      return;
    }

    if (event.key.toLowerCase() === "f") {
      this.tryFoundCity();
      return;
    }

    const step = event.shiftKey ? 2 : 1;
    if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") {
      this.camera.x = Math.max(0, this.camera.x - step);
    } else if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") {
      this.camera.x = Math.min(MAP_WIDTH - VIEW_WIDTH, this.camera.x + step);
    } else if (event.key === "ArrowUp" || event.key.toLowerCase() === "w") {
      this.camera.y = Math.max(0, this.camera.y - step);
    } else if (event.key === "ArrowDown" || event.key.toLowerCase() === "s") {
      this.camera.y = Math.min(MAP_HEIGHT - VIEW_HEIGHT, this.camera.y + step);
    }
  }

  issueUnitOrder(unit, targetX, targetY) {
    if (unit.movesLeft <= 0) {
      this.log("La unidad ya gasto todos sus movimientos.");
      return;
    }

    const targetUnit = this.getUnitAt(targetX, targetY);
    if (targetUnit && targetUnit.ownerId !== unit.ownerId) {
      if (this.distance(unit.x, unit.y, targetX, targetY) !== 1) {
        this.log("Solo puedes atacar enemigos adyacentes.");
        return;
      }
      if (UNIT_TYPES[unit.type].attack <= 0) {
        this.log("Esa unidad no puede atacar.");
        return;
      }
      this.resolveCombat(unit, targetUnit);
      this.refreshVisibility(this.currentPlayer);
      this.checkVictory();
      return;
    }

    const targetCity = this.getCityAt(targetX, targetY);
    if (targetCity && targetCity.ownerId !== unit.ownerId && UNIT_TYPES[unit.type].attack <= 0) {
      this.log("Un colono no puede capturar una ciudad.");
      return;
    }

    const reachable = this.getReachableTiles(unit, Boolean(targetCity && targetCity.ownerId !== unit.ownerId));
    const key = this.key(targetX, targetY);
    if (!reachable.has(key)) {
      this.log("Destino fuera de alcance o bloqueado.");
      return;
    }
    const path = this.reconstructPath(reachable, key);
    if (path.length === 0) {
      return;
    }
    this.moveUnitAlongPath(unit, path);

    const enemyCity = this.getCityAt(unit.x, unit.y);
    if (enemyCity && enemyCity.ownerId !== unit.ownerId) {
      this.captureCity(unit, enemyCity);
    }

    this.refreshVisibility(this.currentPlayer);
    this.checkVictory();
  }

  getReachableTiles(unit, allowEnemyCityDestination = false) {
    const frontier = [{ x: unit.x, y: unit.y, cost: 0 }];
    const visited = new Map();
    visited.set(this.key(unit.x, unit.y), { cost: 0, prev: null });

    while (frontier.length > 0) {
      frontier.sort((a, b) => a.cost - b.cost);
      const current = frontier.shift();
      const dirs = [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ];

      dirs.forEach(([dx, dy]) => {
        const nx = current.x + dx;
        const ny = current.y + dy;
        if (!this.inBounds(nx, ny)) {
          return;
        }
        const tile = this.getTile(nx, ny);
        const terrain = TERRAIN[tile.terrain];
        if (terrain.moveCost > unit.movesLeft) {
          return;
        }
        const newCost = current.cost + terrain.moveCost;
        if (newCost > unit.movesLeft) {
          return;
        }

        const occupant = this.getUnitAt(nx, ny);
        if (occupant && occupant.id !== unit.id) {
          return;
        }

        const city = this.getCityAt(nx, ny);
        if (city && city.ownerId !== unit.ownerId && !allowEnemyCityDestination) {
          return;
        }

        const mapKey = this.key(nx, ny);
        const existing = visited.get(mapKey);
        if (!existing || newCost < existing.cost) {
          visited.set(mapKey, { cost: newCost, prev: this.key(current.x, current.y) });
          frontier.push({ x: nx, y: ny, cost: newCost });
        }
      });
    }

    visited.delete(this.key(unit.x, unit.y));
    return visited;
  }

  reconstructPath(reachable, targetKey) {
    const path = [];
    let cursor = targetKey;
    while (cursor) {
      const entry = reachable.get(cursor);
      if (!entry) {
        break;
      }
      const [x, y] = cursor.split(",").map(Number);
      path.unshift({ x, y });
      cursor = entry.prev;
      if (cursor && !reachable.has(cursor)) {
        break;
      }
    }
    return path;
  }

  moveUnitAlongPath(unit, path) {
    path.forEach((step) => {
      const tile = this.getTile(step.x, step.y);
      const cost = TERRAIN[tile.terrain].moveCost;
      if (unit.movesLeft >= cost) {
        unit.x = step.x;
        unit.y = step.y;
        unit.movesLeft -= cost;
      }
    });
    this.centerCameraOn(unit.x, unit.y);
  }

  resolveCombat(attacker, defender) {
    const attackerDef = UNIT_TYPES[attacker.type];
    const defenderDef = UNIT_TYPES[defender.type];
    const defenseTile = TERRAIN[this.getTile(defender.x, defender.y).terrain];

    const attackRoll = attackerDef.attack + this.randomInt(1, 4) + Math.floor(attacker.hp / 3);
    const defenseRoll = defenderDef.attack + defenseTile.defense + this.randomInt(1, 3) + Math.floor(defender.hp / 4);
    const dealt = Math.max(2, attackRoll - Math.floor(defenseRoll / 2));
    const retaliation = Math.max(1, Math.floor(defenseRoll / 2));

    defender.hp -= dealt;
    attacker.movesLeft = 0;

    if (defender.hp > 0) {
      attacker.hp -= retaliation;
    }

    if (defender.hp <= 0) {
      this.log(`${UNIT_TYPES[attacker.type].name} derrota a ${UNIT_TYPES[defender.type].name}.`);
      const targetX = defender.x;
      const targetY = defender.y;
      this.removeUnit(defender);
      if (attacker.hp > 0) {
        attacker.x = targetX;
        attacker.y = targetY;
      }
    } else {
      this.log(`${UNIT_TYPES[attacker.type].name} golpea por ${dealt} de dano.`);
    }

    if (attacker.hp <= 0) {
      this.log(`${UNIT_TYPES[attacker.type].name} cae en combate.`);
      this.removeUnit(attacker);
    }
  }

  captureCity(unit, city) {
    const oldOwner = this.players[city.ownerId];
    oldOwner.cities = oldOwner.cities.filter((entry) => entry.id !== city.id);
    city.ownerId = unit.ownerId;
    city.hp = Math.max(12, city.hp);
    city.queue = "warrior";
    this.players[unit.ownerId].cities.push(city);
    this.log(`${this.players[unit.ownerId].name} captura ${city.name}.`);
    this.checkVictory();
  }

  runAITurn(player) {
    this.log(`${player.name} esta resolviendo su turno.`);
    this.chooseAIProduction(player);

    const units = [...player.units];
    units.forEach((unit) => {
      if (!player.units.find((entry) => entry.id === unit.id)) {
        return;
      }
      if (unit.type === "settler") {
        this.runAISettler(unit);
        return;
      }

      if (this.attackAdjacentEnemy(unit)) {
        return;
      }

      const target = this.findNearestEnemyTarget(unit.x, unit.y, player.id);
      if (target) {
        this.moveUnitToward(unit, target.x, target.y, true);
      } else {
        this.wanderUnit(unit);
      }

      this.captureIfStandingOnEnemyCity(unit);

      this.attackAdjacentEnemy(unit);
    });
  }

  runAISettler(unit) {
    if (this.canFoundCity(unit) && this.scoreCitySite(unit.x, unit.y) >= 18) {
      this.createCity(unit.ownerId, unit.x, unit.y);
      this.removeUnit(unit);
      return;
    }

    let bestTarget = null;
    let bestScore = -Infinity;
    for (let y = Math.max(1, unit.y - 6); y <= Math.min(MAP_HEIGHT - 2, unit.y + 6); y += 1) {
      for (let x = Math.max(1, unit.x - 6); x <= Math.min(MAP_WIDTH - 2, unit.x + 6); x += 1) {
        if (!this.canSettleAt(x, y)) {
          continue;
        }
        const score = this.scoreCitySite(x, y) - this.distance(unit.x, unit.y, x, y);
        if (score > bestScore) {
          bestScore = score;
          bestTarget = { x, y };
        }
      }
    }

    if (bestTarget) {
      this.moveUnitToward(unit, bestTarget.x, bestTarget.y, true);
      if (this.canFoundCity(unit) && this.scoreCitySite(unit.x, unit.y) >= 16) {
        this.createCity(unit.ownerId, unit.x, unit.y);
        this.removeUnit(unit);
      }
      return;
    }

    this.wanderUnit(unit);
  }

  canSettleAt(x, y) {
    const tile = this.getTile(x, y);
    if (!tile || tile.terrain === "water" || this.getCityAt(x, y) || this.getUnitAt(x, y)) {
      return false;
    }
    for (const player of this.players) {
      for (const city of player.cities) {
        if (this.distance(x, y, city.x, city.y) < 5) {
          return false;
        }
      }
    }
    return true;
  }

  scoreCitySite(x, y) {
    let score = 0;
    for (let oy = -1; oy <= 1; oy += 1) {
      for (let ox = -1; ox <= 1; ox += 1) {
        const tile = this.getTile(x + ox, y + oy);
        if (!tile) {
          score -= 2;
          continue;
        }
        const data = TERRAIN[tile.terrain];
        score += data.food * 2 + data.production * 2 + data.gold;
        if (tile.terrain === "water") {
          score -= 2;
        }
      }
    }
    return score;
  }

  attackAdjacentEnemy(unit) {
    if (UNIT_TYPES[unit.type].attack <= 0 || unit.movesLeft <= 0) {
      return false;
    }
    const neighbors = [
      [unit.x + 1, unit.y],
      [unit.x - 1, unit.y],
      [unit.x, unit.y + 1],
      [unit.x, unit.y - 1],
    ];
    for (const [x, y] of neighbors) {
      const enemy = this.getUnitAt(x, y);
      if (enemy && enemy.ownerId !== unit.ownerId) {
        this.resolveCombat(unit, enemy);
        return true;
      }
      const city = this.getCityAt(x, y);
      if (city && city.ownerId !== unit.ownerId) {
        const reachable = this.getReachableTiles(unit, true);
        const path = this.reconstructPath(reachable, this.key(x, y));
        if (path.length > 0) {
          this.moveUnitAlongPath(unit, path);
          this.captureCity(unit, city);
          return true;
        }
      }
    }
    return false;
  }

  findNearestEnemyTarget(x, y, ownerId) {
    let best = null;
    let bestDistance = Infinity;
    this.players.forEach((player) => {
      if (player.id === ownerId) {
        return;
      }
      player.cities.forEach((city) => {
        const dist = this.distance(x, y, city.x, city.y);
        if (dist < bestDistance) {
          bestDistance = dist;
          best = { x: city.x, y: city.y };
        }
      });
      player.units.forEach((unit) => {
        const dist = this.distance(x, y, unit.x, unit.y);
        if (dist < bestDistance) {
          bestDistance = dist;
          best = { x: unit.x, y: unit.y };
        }
      });
    });
    return best;
  }

  moveUnitToward(unit, targetX, targetY, settleIntent = false) {
    if (unit.movesLeft <= 0) {
      return;
    }
    const reachable = this.getReachableTiles(unit, settleIntent);
    let bestKey = null;
    let bestDistance = Infinity;
    reachable.forEach((entry, key) => {
      const [x, y] = key.split(",").map(Number);
      const dist = this.distance(x, y, targetX, targetY);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestKey = key;
      } else if (dist === bestDistance && entry.cost < reachable.get(bestKey)?.cost) {
        bestKey = key;
      }
    });
    if (!bestKey) {
      return;
    }
    const path = this.reconstructPath(reachable, bestKey);
    this.moveUnitAlongPath(unit, path);
  }

  wanderUnit(unit) {
    const reachableMap = this.getReachableTiles(unit);
    const reachable = Array.from(reachableMap.keys());
    if (reachable.length === 0) {
      return;
    }
    const targetKey = reachable[this.randomInt(0, reachable.length - 1)];
    const path = this.reconstructPath(reachableMap, targetKey);
    this.moveUnitAlongPath(unit, path);
  }

  refreshVisibility(player) {
    player.visible = new Set();
    const reveal = (x, y, range) => {
      for (let oy = -range; oy <= range; oy += 1) {
        for (let ox = -range; ox <= range; ox += 1) {
          const tx = x + ox;
          const ty = y + oy;
          if (!this.inBounds(tx, ty) || Math.abs(ox) + Math.abs(oy) > range) {
            continue;
          }
          const key = this.key(tx, ty);
          player.visible.add(key);
          player.explored.add(key);
        }
      }
    };

    player.units.forEach((unit) => {
      reveal(unit.x, unit.y, UNIT_TYPES[unit.type].vision);
    });
    player.cities.forEach((city) => reveal(city.x, city.y, 3));
  }

  isVisibleToPlayer(player, x, y) {
    return player.visible.has(this.key(x, y));
  }

  captureIfStandingOnEnemyCity(unit) {
    if (!unit || UNIT_TYPES[unit.type].attack <= 0) {
      return;
    }
    const city = this.getCityAt(unit.x, unit.y);
    if (city && city.ownerId !== unit.ownerId) {
      this.captureCity(unit, city);
    }
  }

  checkVictory() {
    const alive = this.players.filter((player) => player.cities.length > 0 || player.units.length > 0);
    if (alive.length === 1) {
      this.winner = alive[0];
      this.ui.winnerBanner.classList.remove("hidden");
      this.ui.winnerBanner.textContent = `${alive[0].name} domina el mundo. Pulsa "Nuevo mundo" para reiniciar.`;
    } else {
      this.ui.winnerBanner.classList.add("hidden");
      this.ui.winnerBanner.textContent = "";
    }
  }

  centerCameraOnPlayer(player) {
    const anchor = player.units[0] || player.cities[0];
    if (anchor) {
      this.centerCameraOn(anchor.x, anchor.y);
    }
  }

  centerCameraOn(x, y) {
    this.camera.x = this.clamp(x - Math.floor(VIEW_WIDTH / 2), 0, MAP_WIDTH - VIEW_WIDTH);
    this.camera.y = this.clamp(y - Math.floor(VIEW_HEIGHT / 2), 0, MAP_HEIGHT - VIEW_HEIGHT);
  }

  screenToTile(event) {
    const rect = this.canvas.getBoundingClientRect();
    const scaleX = this.canvas.width / rect.width;
    const scaleY = this.canvas.height / rect.height;
    const mouseX = (event.clientX - rect.left) * scaleX;
    const mouseY = (event.clientY - rect.top) * scaleY;
    const tileX = Math.floor(mouseX / TILE_SIZE) + this.camera.x;
    const tileY = Math.floor(mouseY / TILE_SIZE) + this.camera.y;
    if (!this.inBounds(tileX, tileY)) {
      return null;
    }
    return { x: tileX, y: tileY };
  }

  updateTileInfo() {
    if (!this.hoverTile) {
      this.ui.hoverCoords.textContent = "-";
      this.ui.tileInfo.textContent = "Mueve el cursor sobre el mapa para inspeccionar casillas.";
      return;
    }

    const { x, y } = this.hoverTile;
    this.ui.hoverCoords.textContent = `${x}, ${y}`;
    const player = this.currentPlayer;
    const explored = player.explored.has(this.key(x, y));
    if (!explored) {
      this.ui.tileInfo.textContent = "Territorio no explorado.";
      return;
    }

    const tile = this.getTile(x, y);
    const terrain = TERRAIN[tile.terrain];
    const unit = this.getUnitAt(x, y);
    const city = this.getCityAt(x, y);
    const lines = [
      `Terreno: ${terrain.name}`,
      `Rendimiento: +${terrain.food} comida, +${terrain.production} produccion, +${terrain.gold} oro`,
      `Movimiento: ${terrain.moveCost >= 999 ? "Bloqueado" : terrain.moveCost}`,
    ];

    if (city && this.isVisibleToPlayer(player, x, y)) {
      lines.push(`Ciudad: ${city.name} (${this.players[city.ownerId].name})`);
      lines.push(`Poblacion: ${city.population}`);
    }
    if (unit && this.isVisibleToPlayer(player, x, y)) {
      lines.push(`Unidad: ${UNIT_TYPES[unit.type].name} (${this.players[unit.ownerId].name})`);
      lines.push(`HP: ${unit.hp}`);
    }
    this.ui.tileInfo.textContent = lines.join("\n");
  }

  syncUI() {
    const player = this.currentPlayer;
    this.ui.turn.textContent = String(this.turn);
    this.ui.activePlayer.textContent = player.name;
    this.ui.gold.textContent = String(player.gold);
    this.ui.science.textContent = String(player.science);
    this.ui.cityCount.textContent = String(player.cities.length);
    this.ui.unitCount.textContent = String(player.units.length);

    const unit = this.getSelectedUnit();
    const city = this.getSelectedCity();
    if (unit) {
      const reachable = this.getReachableTiles(unit);
      this.ui.selectionMode.textContent = UNIT_TYPES[unit.type].name;
      this.ui.selectionInfo.textContent = [
        `Posicion: ${unit.x}, ${unit.y}`,
        `HP: ${unit.hp}/${UNIT_TYPES[unit.type].hp}`,
        `Movimientos: ${unit.movesLeft}/${UNIT_TYPES[unit.type].moves}`,
        `Ataque: ${UNIT_TYPES[unit.type].attack}`,
        `Vision: ${UNIT_TYPES[unit.type].vision}`,
        `Alcance actual: ${reachable.size} casillas`,
      ].join("\n");
    } else if (city) {
      this.ui.selectionMode.textContent = city.name;
      this.ui.selectionInfo.textContent = [
        `Poblacion: ${city.population}`,
        `Comida acumulada: ${city.food}`,
        `Produccion acumulada: ${city.production}`,
        `Cola actual: ${city.queue ? UNIT_TYPES[city.queue].name : "Sin produccion"}`,
        `HP urbano: ${city.hp}`,
      ].join("\n");
    } else {
      this.ui.selectionMode.textContent = "Nada";
      this.ui.selectionInfo.textContent = "Selecciona una unidad o ciudad para ver detalles y acciones.";
    }

    this.ui.buttons.foundCity.disabled = !unit || !this.canFoundCity(unit) || !player.isHuman;
    this.ui.buttons.queueWarrior.disabled = !city || !player.isHuman;
    this.ui.buttons.queueScout.disabled = !city || !player.isHuman;
    this.ui.buttons.queueSettler.disabled = !city || !player.isHuman || city.population < 2;
    this.ui.buttons.endTurn.disabled = !player.isHuman || Boolean(this.winner);

    this.ui.eventLog.replaceChildren();
    this.messages.slice(-10).forEach((message) => {
      const item = document.createElement("li");
      item.textContent = message;
      this.ui.eventLog.appendChild(item);
    });

    this.updateTileInfo();
  }

  loop() {
    this.render();
    window.requestAnimationFrame(() => this.loop());
  }

  render() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    const humanPlayer = this.players[0];

    for (let sy = 0; sy < VIEW_HEIGHT; sy += 1) {
      for (let sx = 0; sx < VIEW_WIDTH; sx += 1) {
        const worldX = sx + this.camera.x;
        const worldY = sy + this.camera.y;
        const drawX = sx * TILE_SIZE;
        const drawY = sy * TILE_SIZE;
        this.drawTile(worldX, worldY, drawX, drawY, humanPlayer);
      }
    }

    this.drawReachableOverlay();
    this.drawCities(humanPlayer);
    this.drawUnits(humanPlayer);
    this.drawSelection();
    this.drawHover();
    this.drawGrid();
    this.drawMinimap(humanPlayer);
  }

  drawTile(worldX, worldY, drawX, drawY, humanPlayer) {
    const tile = this.getTile(worldX, worldY);
    const explored = humanPlayer.explored.has(this.key(worldX, worldY));
    if (!explored) {
      this.ctx.fillStyle = "#05080c";
      this.ctx.fillRect(drawX, drawY, TILE_SIZE, TILE_SIZE);
      return;
    }

    const data = TERRAIN[tile.terrain];
    this.ctx.fillStyle = data.color;
    this.ctx.fillRect(drawX, drawY, TILE_SIZE, TILE_SIZE);
    this.drawTerrainPattern(tile.terrain, worldX, worldY, drawX, drawY);

    if (!humanPlayer.visible.has(this.key(worldX, worldY))) {
      this.ctx.fillStyle = "rgba(6, 10, 14, 0.55)";
      this.ctx.fillRect(drawX, drawY, TILE_SIZE, TILE_SIZE);
    }
  }

  drawTerrainPattern(type, worldX, worldY, drawX, drawY) {
    const seed = (worldX * 97 + worldY * 57) % 7;
    if (type === "water") {
      this.ctx.fillStyle = "#9bd6ff";
      for (let i = 0; i < 3; i += 1) {
        this.ctx.fillRect(drawX + 4 + i * 8, drawY + ((seed + i * 2) % 4) * 3 + 5, 4, 2);
      }
      return;
    }
    if (type === "grass") {
      this.ctx.fillStyle = "#bce29d";
      for (let i = 0; i < 5; i += 1) {
        this.ctx.fillRect(drawX + 3 + ((seed + i * 5) % 24), drawY + 6 + ((seed + i * 3) % 18), 2, 3);
      }
      return;
    }
    if (type === "plains") {
      this.ctx.fillStyle = "#ead799";
      for (let i = 0; i < 4; i += 1) {
        this.ctx.fillRect(drawX + 4 + i * 6, drawY + 10 + ((seed + i * 4) % 10), 4, 1);
      }
      return;
    }
    if (type === "forest") {
      this.ctx.fillStyle = "#17351b";
      for (let i = 0; i < 4; i += 1) {
        this.ctx.fillRect(drawX + 4 + ((seed + i * 6) % 18), drawY + 6 + ((i * 4) % 14), 5, 6);
      }
      return;
    }
    if (type === "hill") {
      this.ctx.fillStyle = "#5d4a36";
      this.ctx.fillRect(drawX + 4, drawY + 18, 24, 4);
      this.ctx.fillRect(drawX + 8, drawY + 14, 16, 4);
      this.ctx.fillRect(drawX + 12, drawY + 10, 8, 4);
    }
  }

  drawCities(humanPlayer) {
    this.players.forEach((player) => {
      player.cities.forEach((city) => {
        if (!this.isInView(city.x, city.y) || !humanPlayer.visible.has(this.key(city.x, city.y))) {
          return;
        }
        const drawX = (city.x - this.camera.x) * TILE_SIZE + 4;
        const drawY = (city.y - this.camera.y) * TILE_SIZE + 4;
        this.drawSprite(SPRITES.city, drawX, drawY, 2, { A: player.color, B: player.dark, C: "#e7dcb6", D: "#4d3120" });
      });
    });
  }

  drawUnits(humanPlayer) {
    this.players.forEach((player) => {
      player.units.forEach((unit) => {
        if (!this.isInView(unit.x, unit.y) || !humanPlayer.visible.has(this.key(unit.x, unit.y))) {
          return;
        }
        const sprite = SPRITES[unit.type];
        const drawX = (unit.x - this.camera.x) * TILE_SIZE + 8;
        const drawY = (unit.y - this.camera.y) * TILE_SIZE + 8;
        this.drawSprite(sprite, drawX, drawY, 2, { A: player.color, B: "#f7f0d0", C: player.dark, D: "#1b1510", E: "#a7d7ff" });

        this.ctx.fillStyle = "#111820";
        this.ctx.fillRect(drawX, drawY - 5, 16, 3);
        this.ctx.fillStyle = unit.ownerId === 0 ? "#6adf7a" : "#ff9a8b";
        this.ctx.fillRect(drawX, drawY - 5, Math.max(1, Math.floor((unit.hp / UNIT_TYPES[unit.type].hp) * 16)), 3);
      });
    });
  }

  drawReachableOverlay() {
    const unit = this.getSelectedUnit();
    if (!unit) {
      return;
    }
    const reachable = this.getReachableTiles(unit);
    reachable.forEach((_entry, key) => {
      const [x, y] = key.split(",").map(Number);
      if (!this.isInView(x, y)) {
        return;
      }
      const drawX = (x - this.camera.x) * TILE_SIZE;
      const drawY = (y - this.camera.y) * TILE_SIZE;
      this.ctx.fillStyle = "rgba(255, 191, 86, 0.22)";
      this.ctx.fillRect(drawX + 2, drawY + 2, TILE_SIZE - 4, TILE_SIZE - 4);
    });
  }

  drawSelection() {
    const unit = this.getSelectedUnit();
    const city = this.getSelectedCity();
    if (unit && this.isInView(unit.x, unit.y)) {
      const drawX = (unit.x - this.camera.x) * TILE_SIZE;
      const drawY = (unit.y - this.camera.y) * TILE_SIZE;
      this.ctx.strokeStyle = "#ffd15f";
      this.ctx.lineWidth = 3;
      this.ctx.strokeRect(drawX + 2, drawY + 2, TILE_SIZE - 4, TILE_SIZE - 4);
    }
    if (city && this.isInView(city.x, city.y)) {
      const drawX = (city.x - this.camera.x) * TILE_SIZE;
      const drawY = (city.y - this.camera.y) * TILE_SIZE;
      this.ctx.strokeStyle = "#81e2ff";
      this.ctx.lineWidth = 3;
      this.ctx.strokeRect(drawX + 2, drawY + 2, TILE_SIZE - 4, TILE_SIZE - 4);
    }
  }

  drawHover() {
    if (!this.hoverTile || !this.isInView(this.hoverTile.x, this.hoverTile.y)) {
      return;
    }
    const drawX = (this.hoverTile.x - this.camera.x) * TILE_SIZE;
    const drawY = (this.hoverTile.y - this.camera.y) * TILE_SIZE;
    this.ctx.strokeStyle = "rgba(255,255,255,0.55)";
    this.ctx.lineWidth = 1;
    this.ctx.strokeRect(drawX + 1, drawY + 1, TILE_SIZE - 2, TILE_SIZE - 2);
  }

  drawGrid() {
    this.ctx.strokeStyle = "rgba(0, 0, 0, 0.16)";
    this.ctx.lineWidth = 1;
    for (let x = 0; x <= VIEW_WIDTH; x += 1) {
      this.ctx.beginPath();
      this.ctx.moveTo(x * TILE_SIZE, 0);
      this.ctx.lineTo(x * TILE_SIZE, VIEW_HEIGHT * TILE_SIZE);
      this.ctx.stroke();
    }
    for (let y = 0; y <= VIEW_HEIGHT; y += 1) {
      this.ctx.beginPath();
      this.ctx.moveTo(0, y * TILE_SIZE);
      this.ctx.lineTo(VIEW_WIDTH * TILE_SIZE, y * TILE_SIZE);
      this.ctx.stroke();
    }
  }

  drawMinimap(humanPlayer) {
    const tileW = this.minimapCanvas.width / MAP_WIDTH;
    const tileH = this.minimapCanvas.height / MAP_HEIGHT;
    this.minimapCtx.clearRect(0, 0, this.minimapCanvas.width, this.minimapCanvas.height);

    for (let y = 0; y < MAP_HEIGHT; y += 1) {
      for (let x = 0; x < MAP_WIDTH; x += 1) {
        const key = this.key(x, y);
        if (!humanPlayer.explored.has(key)) {
          this.minimapCtx.fillStyle = "#05080c";
        } else {
          this.minimapCtx.fillStyle = TERRAIN[this.getTile(x, y).terrain].color;
          if (!humanPlayer.visible.has(key)) {
            this.minimapCtx.fillStyle = "#243647";
          }
        }
        this.minimapCtx.fillRect(x * tileW, y * tileH, Math.ceil(tileW), Math.ceil(tileH));
      }
    }

    this.players.forEach((player) => {
      player.cities.forEach((city) => {
        if (!humanPlayer.visible.has(this.key(city.x, city.y))) {
          return;
        }
        this.minimapCtx.fillStyle = player.color;
        this.minimapCtx.fillRect(city.x * tileW, city.y * tileH, Math.max(2, tileW + 1), Math.max(2, tileH + 1));
      });
    });

    this.minimapCtx.strokeStyle = "#ffbf56";
    this.minimapCtx.lineWidth = 1;
    this.minimapCtx.strokeRect(this.camera.x * tileW, this.camera.y * tileH, VIEW_WIDTH * tileW, VIEW_HEIGHT * tileH);
  }

  drawSprite(sprite, x, y, scale, palette) {
    sprite.forEach((row, rowIndex) => {
      [...row].forEach((cell, cellIndex) => {
        if (cell === ".") {
          return;
        }
        this.ctx.fillStyle = palette[cell] || "#ffffff";
        this.ctx.fillRect(x + cellIndex * scale, y + rowIndex * scale, scale, scale);
      });
    });
  }

  findFreeAdjacent(x, y) {
    const options = [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1], [x + 1, y + 1], [x - 1, y - 1]];
    for (const [nx, ny] of options) {
      const tile = this.getTile(nx, ny);
      if (!tile || tile.terrain === "water" || this.getUnitAt(nx, ny) || this.getCityAt(nx, ny)) {
        continue;
      }
      return [nx, ny];
    }
    return null;
  }

  log(message) {
    this.messages.push(message);
    if (this.messages.length > 10) {
      this.messages = this.messages.slice(-10);
    }
  }

  inBounds(x, y) {
    return x >= 0 && y >= 0 && x < MAP_WIDTH && y < MAP_HEIGHT;
  }

  isInView(x, y) {
    return x >= this.camera.x && y >= this.camera.y && x < this.camera.x + VIEW_WIDTH && y < this.camera.y + VIEW_HEIGHT;
  }

  distance(ax, ay, bx, by) {
    return Math.abs(ax - bx) + Math.abs(ay - by);
  }

  key(x, y) {
    return `${x},${y}`;
  }

  clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }
}

window.addEventListener("load", () => {
  new CivGame();
});
