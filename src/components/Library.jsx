import { useState } from "react";
import {
  Search,
  Dumbbell,
  ArrowUpRight,
  Activity,
  Footprints,
  BicepsFlexed,
  StretchHorizontal,
  StretchVertical,
  MoveUp,
} from "lucide-react";
import { PageHeading, Empty, Button } from "./UI";
import { exercises } from "../data";
import ExerciseGuide from "./ExerciseGuide";
const muscleIcons = {
  Chest: StretchHorizontal,
  Back: StretchVertical,
  Shoulders: MoveUp,
  Arms: BicepsFlexed,
  Legs: Footprints,
  Core: Activity,
};
export default function Library() {
  const [query, setQuery] = useState("");
  const [muscle, setMuscle] = useState("All muscles");
  const [equipment, setEquipment] = useState("All equipment");
  const [selected, setSelected] = useState(null);
  const filtered = exercises.filter(
    (e) =>
      `${e.name} ${e.muscle} ${e.equipment}`
        .toLowerCase()
        .includes(query.trim().toLowerCase()) &&
      (muscle === "All muscles" || e.muscle === muscle) &&
      (equipment === "All equipment" || e.equipment === equipment),
  );
  return (
    <>
      <PageHeading
        title="Good form. Better sessions."
        subtitle="Get to know your next movement. Explore your exercise library."
      />
      <div className="library-toolbar">
        <div className="search-field">
          <Search size={19} />
          <input
            placeholder="Search exercises, muscles, equipment…"
            aria-label="Search exercise library"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <select
          aria-label="Filter by equipment"
          value={equipment}
          onChange={(e) => setEquipment(e.target.value)}
        >
          {["All equipment", ...new Set(exercises.map((e) => e.equipment))].map(
            (s) => (
              <option key={s}>{s}</option>
            ),
          )}
        </select>
      </div>
      <div className="filter-tabs">
        {[
          "All muscles",
          "Chest",
          "Back",
          "Shoulders",
          "Arms",
          "Legs",
          "Core",
        ].map((s) => (
          <button
            key={s}
            onClick={() => setMuscle(s)}
            aria-pressed={muscle === s}
            className={muscle === s ? "active" : ""}
          >
            {s}
          </button>
        ))}
      </div>
      <div className="section-title">
        <h2>
          {muscle === "All muscles" ? "All exercises" : `${muscle} exercises`}
        </h2>
        <span className="small muted">{filtered.length} movements</span>
      </div>
      <div className="library-grid">
        {filtered.map((e) => {
          const Icon = muscleIcons[e.muscle] || Dumbbell;
          return (
            <button
              key={e.id}
              className="library-card"
              onClick={() => setSelected(e)}
            >
              <span
                className={`muscle-illustration muscle-${e.muscle.toLowerCase()}`}
              >
                <Icon size={30} strokeWidth={1.4} />
                <span>{e.muscle}</span>
              </span>
              <div>
                <h3>{e.name}</h3>
                <p>{e.equipment}</p>
              </div>
              <ArrowUpRight size={19} />
            </button>
          );
        })}
      </div>
      {!filtered.length && (
        <Empty
          icon={Search}
          title="No matching movements"
          description="Try a different name, muscle group, or piece of equipment."
        >
          <Button
            variant="secondary"
            onClick={() => {
              setQuery("");
              setMuscle("All muscles");
              setEquipment("All equipment");
            }}
          >
            Clear filters
          </Button>
        </Empty>
      )}
      {selected && (
        <ExerciseGuide exercise={selected} onClose={() => setSelected(null)} />
      )}
    </>
  );
}
