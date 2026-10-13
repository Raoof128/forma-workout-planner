import { useDeferredValue, useMemo, useState } from "react";
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
import { selectableExercises as exercises } from "../data";
import ExerciseGuide from "./ExerciseGuide";
import { matchesExercise } from "../catalog/search";
import { matchesEquipment } from "../catalog/curation.js";
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
  const [visible, setVisible] = useState(24);
  const [category, setCategory] = useState("All activities");
  const deferredQuery = useDeferredValue(query);
  const filtered = useMemo(
    () =>
      exercises.filter(
        (e) =>
          matchesExercise(e, deferredQuery) &&
          (muscle === "All muscles" || e.muscle === muscle) &&
          (equipment === "All equipment" || matchesEquipment(e, equipment)) &&
          (category === "All activities" ||
            (e.category ?? "strength") === category),
      ),
    [deferredQuery, muscle, equipment, category],
  );
  return (
    <>
      <PageHeading
        eyebrow="Know your movement"
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
            onChange={(e) => {
              setQuery(e.target.value);
              setVisible(24);
            }}
          />
        </div>
        <select
          aria-label="Filter by equipment"
          value={equipment}
          onChange={(e) => {
            setEquipment(e.target.value);
            setVisible(24);
          }}
        >
          {[
            "All equipment",
            ...new Set(
              exercises.flatMap((e) => e.equipmentTags ?? [e.equipment]),
            ),
          ].map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
        <select
          aria-label="Filter by activity"
          value={category}
          onChange={(e) => {
            setCategory(e.target.value);
            setVisible(24);
          }}
        >
          {[
            "All activities",
            ...new Set(exercises.map((e) => e.category ?? "strength")),
          ].map((value) => (
            <option key={value}>{value}</option>
          ))}
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
          "Full body",
        ].map((s) => (
          <button
            key={s}
            onClick={() => {
              setMuscle(s);
              setVisible(24);
            }}
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
        <span className="small muted" role="status">
          {filtered.length} {filtered.length === 1 ? "movement" : "movements"}
        </span>
      </div>
      <div className="library-grid">
        {filtered.slice(0, visible).map((e) => {
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
      {filtered.length > visible && (
        <div className="catalog-more">
          <p className="small muted">
            Showing {Math.min(visible, filtered.length)} of {filtered.length}{" "}
            movements
          </p>
          <Button
            variant="secondary"
            onClick={() => setVisible((count) => count + 24)}
          >
            Show more exercises
          </Button>
        </div>
      )}
      <p className="small muted catalog-sources">
        {exercises.length.toLocaleString()} movements across strength,
        conditioning and mobility. Source and licence details are included in
        each guide. This catalog can grow as new movements are documented.
      </p>
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
              setCategory("All activities");
              setVisible(24);
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
