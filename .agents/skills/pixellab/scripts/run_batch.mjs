import { generateAndSave } from './generate_batch.mjs';

const tasks = [
  {
    name: 'chicken_egg',
    params: {
      description: '16x16 pixel art icon of a smooth brown chicken egg, warm tan shell, dark outline, RPG inventory item sprite',
      width: 16,
      height: 16,
      no_background: true,
      outline: 'single color outline',
      detail: 'low detail'
    },
    outputPath: 'assets/Icons/animal_produces/chicken_egg.png'
  },
  {
    name: 'duck_egg',
    params: {
      description: '16x16 pixel art icon of a pale celadon duck egg, seafoam greenish blue eggshell, glossy smooth oval, dark outline, RPG inventory item sprite',
      width: 16,
      height: 16,
      no_background: true,
      outline: 'single color outline',
      detail: 'low detail'
    },
    outputPath: 'assets/Icons/animal_produces/duck_egg.png'
  },
  {
    name: 'goose_egg',
    params: {
      description: '16x16 pixel art icon of a large chalky white goose egg, big ivory cream egg, dark outline, RPG inventory item sprite',
      width: 16,
      height: 16,
      no_background: true,
      outline: 'single color outline',
      detail: 'low detail'
    },
    outputPath: 'assets/Icons/animal_produces/goose_egg.png'
  },
  {
    name: 'floral_honey',
    params: {
      description: '16x16 pixel art icon of a delicate glass vial of floral nectar, cork stopper with small flower blossom ribbon, golden pink honey nectar, dark outline, RPG item sprite',
      width: 16,
      height: 16,
      no_background: true,
      outline: 'single color outline',
      detail: 'low detail'
    },
    outputPath: 'assets/Icons/honey/floral_honey.png'
  },
  {
    name: 'flower_seed_packet',
    params: {
      description: '16x16 pixel art icon of a paper seed packet for flowers, seed envelope with cute blooming rose emblem, dark outline, RPG inventory item sprite',
      width: 16,
      height: 16,
      no_background: true,
      outline: 'single color outline',
      detail: 'low detail'
    },
    outputPath: 'assets/Icons/seeds/flower_seed_packet.png'
  }
];

async function run() {
  for (const task of tasks) {
    try {
      await generateAndSave(task.name, task.params, task.outputPath);
    } catch (err) {
      console.error(`Error generating ${task.name}:`, err);
      process.exit(1);
    }
  }
  console.log('\nAll 5 items generated successfully!');
}

run();
