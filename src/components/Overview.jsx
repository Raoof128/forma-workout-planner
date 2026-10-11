import { useState } from "react";
import {
  Plus,
  Play,
  Dumbbell,
  Clock,
  ChartNoAxesColumnIncreasing,
  ArrowRight,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { Button, RoutineCard, PageHeading } from "./UI";
import { weekDates, sameDay, dateKey, displayDate } from "../data";
export default function Overview({
  data,
  saved,
  onStart,
  onRoutine,
  onNavigate,
  onSchedule,
}) {
  const [offset, setOffset] = useState(0);
  const dates = weekDates(offset);
  const today = dateKey();
  const [selected, setSelected] = useState(today);
  const [preferred, setPreferred] = useState("");
  const currentWeek = weekDates();
  const counts = currentWeek.map(
    (day) =>
      data.history.filter((session) => sameDay(day, session.date)).length,
  );
  const count = counts.reduce((sum, value) => sum + value, 0);
  const maxCount = Math.max(1, ...counts);
  const lastIndex = data.routines.findIndex(
    (routine) => routine.id === data.history[0]?.routineId,
  );
  const next =
    data.routines.find((routine) => routine.id === preferred) ||
    data.routines[(lastIndex + 1) % data.routines.length];
  const routine = data.active
    ? {
        ...data.routines.find((item) => item.id === data.active.routineId),
        id: data.active.routineId,
        name: data.active.name,
        exercises: data.active.exercises,
        description: "Pick up where you left off.",
      }
    : next;
  const selectedDate =
    dates.find((day) => dateKey(day) === selected) ||
    new Date(`${selected}T12:00:00Z`);
  function moveWeek(delta) {
    const nextOffset = offset + delta;
    setOffset(nextOffset);
    setSelected(dateKey(weekDates(nextOffset)[0]));
  }
  return (
    <>
      <PageHeading
        title="A little stronger, every day."
        subtitle="Your next rep starts here. Let’s make it count."
      >
        <Button onClick={() => onStart(routine)}>
          <Plus size={19} />
          {data.active ? "Resume workout" : "Start workout"}
        </Button>
      </PageHeading>
      <div className="calendar-heading">
        <span>
          {displayDate(dates[0], { day: "numeric", month: "short" })} –{" "}
          {displayDate(dates[6], {
            day: "numeric",
            month: "short",
            year: "numeric",
          })}
        </span>
        {offset !== 0 && (
          <button
            className="text-button"
            onClick={() => {
              setOffset(0);
              setSelected(today);
            }}
          >
            This week
          </button>
        )}
      </div>
      <div className="week-strip">
        <button
          className="week-arrow"
          aria-label="Previous week"
          onClick={() => moveWeek(-1)}
        >
          <ChevronLeft size={16} />
        </button>
        {dates.map((day, index) => {
          const completed = data.history.filter((session) =>
            sameDay(session.date, day),
          ).length;
          const planned = data.schedule.includes(index);
          return (
            <button
              key={dateKey(day)}
              className={`day ${selected === dateKey(day) ? "selected" : ""}`}
              onClick={() => setSelected(dateKey(day))}
              aria-pressed={selected === dateKey(day)}
              aria-label={`${displayDate(day, { weekday: "long", day: "numeric", month: "long" })}, ${completed} workouts logged, ${planned ? "training planned" : "recovery day"}`}
            >
              <span>{displayDate(day, { weekday: "short" })}</span>
              <strong>{day.getUTCDate()}</strong>
              <i
                aria-hidden="true"
                className={completed ? "completed" : planned ? "planned" : ""}
              >
                {completed ? "✓" : planned ? "○" : "·"}
              </i>
            </button>
          );
        })}
        <button
          className="week-arrow"
          aria-label="Next week"
          onClick={() => moveWeek(1)}
        >
          <ChevronRight size={16} />
        </button>
      </div>
      {selected !== today && (
        <div className="day-detail">
          <span>
            {displayDate(selectedDate, {
              weekday: "short",
              day: "numeric",
              month: "long",
            })}
          </span>
          <span>
            {
              data.history.filter((session) =>
                sameDay(session.date, selectedDate),
              ).length
            }{" "}
            workouts logged
          </span>
          <button onClick={onSchedule}>Edit schedule</button>
        </div>
      )}
      <div className="dashboard-top">
        <section className="hero">
          <div className="hero-content">
            <span className="eyebrow">
              {data.active ? "YOUR ACTIVE SESSION" : "YOUR NEXT SESSION"}
            </span>
            <h2>{routine?.name || "Your next chapter"}</h2>
            <p>
              {routine?.description || "Create a routine and make it yours."}
            </p>
            <div className="hero-meta">
              <span>
                <Dumbbell size={19} />
                {routine?.exercises.length || 0} exercises
              </span>
              {routine?.minutes && (
                <span>
                  <Clock size={18} />
                  {routine.minutes} min
                </span>
              )}
              <span>
                <ChartNoAxesColumnIncreasing size={18} />
                {routine?.level || "Your pace"}
              </span>
            </div>
            <Button variant="lime" onClick={() => onStart(routine)}>
              <Play size={18} />
              {data.active ? "Resume workout" : "Start workout"}
            </Button>
            <div className="hero-footer">
              {data.active
                ? saved
                  ? "Your session is saved as you go."
                  : "This session is temporary. Export a copy in Settings."
                : "Your personal training plan · One session at a time"}
            </div>
          </div>
        </section>
        <section className="week-summary panel">
          <div className="section-title">
            <h2>This week</h2>
            <CalendarDays size={19} />
          </div>
          <div className="week-total">
            {count}
            <span> / {data.profile.goal}</span>
          </div>
          <p className="muted">workouts completed</p>
          <div className="week-chart" aria-label="Completed workouts by day">
            {currentWeek.map((day, index) => (
              <div
                key={dateKey(day)}
                aria-label={`${displayDate(day, { weekday: "long" })}: ${counts[index]} workouts`}
              >
                <div className="bar-track">
                  <div
                    className="bar filled"
                    style={{ height: `${(counts[index] / maxCount) * 100}%` }}
                    title={`${counts[index]} ${counts[index] === 1 ? "workout" : "workouts"}`}
                  />
                </div>
                <span>{displayDate(day, { weekday: "short" })}</span>
                <strong>{counts[index]}</strong>
              </div>
            ))}
          </div>
          <div className="week-message">
            <strong>
              {count
                ? "Showing up is getting stronger."
                : "A fresh start. A stronger you."}
            </strong>
            <p>
              {count
                ? `${count} ${count === 1 ? "session" : "sessions"} in the books. Keep building your momentum.`
                : "Consistency builds confidence. Schedule your workouts and make this week yours."}
            </p>
          </div>
        </section>
      </div>
      {!data.active && data.routines.length > 1 && (
        <label className="routine-choice">
          Next session
          <select
            aria-label="Choose next session"
            value={routine?.id || ""}
            onChange={(event) => setPreferred(event.target.value)}
          >
            {data.routines.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </label>
      )}
      <section className="routines-section">
        <div className="section-title">
          <h2>Your routines</h2>
          <button
            className="text-button"
            onClick={() => onNavigate("routines")}
          >
            View all <ArrowRight size={16} />
          </button>
        </div>
        <div className="routine-grid">
          {data.routines.slice(0, 3).map((item) => (
            <RoutineCard key={item.id} routine={item} onClick={onRoutine} />
          ))}
        </div>
      </section>
      <div className="habit-banner">
        <CalendarDays size={27} />
        <div>
          <strong>Build a habit that lasts.</strong>
          <p>
            Plan your workouts for the week and set yourself up for success.
          </p>
        </div>
        <button onClick={onSchedule}>
          Schedule your week <ArrowRight size={18} />
        </button>
      </div>
      <div className="dashboard-footnote">
        <span className="small-status" />
        {saved
          ? "Your space. Your pace. Saved on this device."
          : "Changes are temporary. Export your data in Settings."}
      </div>
    </>
  );
}
