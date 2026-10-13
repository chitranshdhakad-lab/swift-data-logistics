"""Swift Data: a small Flask front end for the delivery logistics database."""
import re
import uuid
from datetime import date, timedelta

import mysql.connector
from mysql.connector import Error
from flask import Flask, flash, redirect, render_template, request, url_for

from config import DB_CONFIG, SECRET_KEY

app = Flask(__name__)
app.secret_key = SECRET_KEY

STATUSES = ["Booked", "Picked Up", "Arrived at Hub", "Departed Hub",
            "Out for Delivery", "Delivered", "Failed"]
RATES = {"Standard": (80, 25, 4), "Express": (150, 40, 2)}  # base, per kg, days


# ---------- database helpers ----------
def get_conn():
    return mysql.connector.connect(**DB_CONFIG)


def query(sql, params=None):
    """Run a SELECT and return a list of dicts."""
    conn = get_conn()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        return cur.fetchall()
    finally:
        conn.close()


def db_message(err):
    """Turn a MySQL error into a sentence a user can act on."""
    if err.errno == 1644:                      # our SIGNAL messages
        return err.msg
    if err.errno == 1062:
        m = re.search(r"for key '([^']+)'", err.msg or "")
        field = m.group(1).split(".")[-1].replace("_", " ") if m else "value"
        field = {"license no": "licence number", "plate no": "plate number", "tracking number": "tracking number"}.get(field, field)
        return f"That {field} is already used by another record."
    if err.errno == 3819:
        return "A value breaks a rule of the database (check weights and dates)."
    return f"Database error: {err.msg}"


@app.errorhandler(Error)
def handle_db_error(err):
    if getattr(err, "errno", None) in (2003, 1045, 1049, 2002):
        msg = ("Cannot reach the swift_data database. Check that MySQL is running "
               "and that DB_PASSWORD is set (see README).")
    else:
        msg = db_message(err)
    return render_template("error.html", message=msg), 500


# ---------- shared dropdown data ----------
def hubs():
    return query("SELECT hub_id, name, city FROM Hub ORDER BY city")


def customers():
    return query("SELECT customer_id, name, city FROM Customer ORDER BY name")


# ---------- 1. track a shipment ----------
@app.route("/")
def track():
    tn = request.args.get("tracking_number", "").strip().upper()
    shipment, events, late = None, [], False
    if tn:
        rows = query(
            """SELECT s.*, cs.name AS sender, cr.name AS receiver,
                      hs.city AS from_city, hd.city AS to_city
               FROM Shipment s
               JOIN Customer cs ON cs.customer_id = s.sender_id
               JOIN Customer cr ON cr.customer_id = s.receiver_id
               JOIN Hub hs ON hs.hub_id = s.source_hub_id
               JOIN Hub hd ON hd.hub_id = s.dest_hub_id
               WHERE s.tracking_number = %s""", (tn,))
        if rows:
            shipment = rows[0]
            events = query(
                """SELECT te.*, h.name AS hub FROM Tracking_Event te
                   LEFT JOIN Hub h ON h.hub_id = te.hub_id
                   WHERE te.shipment_id = %s
                   ORDER BY te.event_time, te.event_id""", (shipment["shipment_id"],))
            if shipment["delivered_date"]:
                late = shipment["delivered_date"].date() > shipment["expected_date"]
            else:
                late = date.today() > shipment["expected_date"] and \
                    shipment["current_status"] not in ("Delivered",)
    summary = query("SELECT current_status, COUNT(*) AS n FROM Shipment "
                    "GROUP BY current_status ORDER BY n DESC")
    recent = query("SELECT tracking_number, current_status FROM Shipment "
                   "ORDER BY booking_date DESC, shipment_id DESC LIMIT 5")
    return render_template("track.html", tn=tn, shipment=shipment, events=events,
                           late=late, summary=summary, recent=recent)


# ---------- 2. create a shipment ----------
@app.route("/shipments/new", methods=["GET", "POST"])
def new_shipment():
    if request.method == "POST":
        f = request.form
        try:
            sender, receiver = int(f["sender_id"]), int(f["receiver_id"])
            src, dst = int(f["source_hub_id"]), int(f["dest_hub_id"])
            weight = float(f["weight_kg"])
            service = f["service_type"]
            fragile = "is_fragile" in f
        except (KeyError, ValueError):
            flash("Please fill in every field with valid values.", "error")
            return redirect(url_for("new_shipment"))
        if sender == receiver:
            flash("Sender and receiver must be different customers.", "error")
        elif src == dst:
            flash("Pick-up hub and destination hub must be different.", "error")
        elif weight <= 0 or service not in RATES:
            flash("Weight must be above 0 and the service must be Standard or Express.", "error")
        else:
            base, per_kg, days = RATES[service]
            cost = base + per_kg * weight + (50 if fragile else 0)
            expected = date.today() + timedelta(days=days)
            conn = get_conn()
            try:
                cur = conn.cursor()
                conn.start_transaction()
                cur.execute(
                    """INSERT INTO Shipment (tracking_number, sender_id, receiver_id,
                           source_hub_id, dest_hub_id, weight_kg, is_fragile, service_type,
                           expected_date, cost)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    ("TMP" + uuid.uuid4().hex[:12], sender, receiver, src, dst,
                     weight, fragile, service, expected, round(cost, 2)))
                sid = cur.lastrowid
                tn = f"TRK{1000 + sid}"
                cur.execute("UPDATE Shipment SET tracking_number=%s WHERE shipment_id=%s",
                            (tn, sid))
                cur.execute("INSERT INTO Tracking_Event (shipment_id, hub_id, status, remarks) "
                            "VALUES (%s,%s,'Booked','Booking confirmed')", (sid, src))
                conn.commit()
            except Error as err:
                conn.rollback()
                flash(db_message(err), "error")
                return redirect(url_for("new_shipment"))
            finally:
                conn.close()
            flash(f"Shipment booked. Tracking number {tn}, cost Rs {cost:,.2f}, "
                  f"expected by {expected:%d %b %Y}.", "ok")
            return redirect(url_for("track", tracking_number=tn))
        return redirect(url_for("new_shipment"))
    return render_template("new_shipment.html", customers=customers(), hubs=hubs(),
                           rates=RATES)


# ---------- 3. trips and assigning shipments (stored procedure + transaction) ----------
@app.route("/assign", methods=["GET", "POST"])
def assign():
    if request.method == "POST":
        try:
            trip_id, shipment_id = int(request.form["trip_id"]), int(request.form["shipment_id"])
        except (KeyError, ValueError):
            flash("Choose both a trip and a shipment.", "error")
            return redirect(url_for("assign"))
        conn = get_conn()
        try:
            try:
                conn.cursor().callproc("sp_assign_shipment_to_trip", (trip_id, shipment_id))
                conn.commit()
            except Error as proc_err:
                # If stored procedure is not supported on cloud database (e.g. TiDB), run equivalent ACID steps
                if getattr(proc_err, "errno", None) in (1305, 8108, 1064, 1105):
                    cur = conn.cursor(dictionary=True)
                    conn.start_transaction()
                    cur.execute("SELECT vehicle_id, from_hub_id, status FROM Trip WHERE trip_id=%s", (trip_id,))
                    t_row = cur.fetchone()
                    cur.execute("SELECT weight_kg, current_status FROM Shipment WHERE shipment_id=%s", (shipment_id,))
                    s_row = cur.fetchone()
                    cur.execute("SELECT capacity_kg, current_load_kg FROM Vehicle WHERE vehicle_id=%s", (t_row["vehicle_id"],))
                    v_row = cur.fetchone()
                    if v_row["current_load_kg"] + s_row["weight_kg"] > v_row["capacity_kg"]:
                        raise Error(msg="Vehicle capacity exceeded", errno=1644)
                    cur.execute("INSERT INTO Trip_Shipment (trip_id, shipment_id, loaded_at) VALUES (%s, %s, NOW())", (trip_id, shipment_id))
                    cur.execute("UPDATE Vehicle SET current_load_kg = current_load_kg + %s WHERE vehicle_id=%s", (s_row["weight_kg"], t_row["vehicle_id"]))
                    cur.execute("INSERT INTO Tracking_Event (shipment_id, hub_id, status, remarks) VALUES (%s, %s, 'Departed Hub', %s)", (shipment_id, t_row["from_hub_id"], f"Loaded onto trip #{trip_id}"))
                    cur.execute("UPDATE Shipment SET current_status='In Transit' WHERE shipment_id=%s", (shipment_id,))
                    conn.commit()
                else:
                    raise proc_err
            flash("Shipment loaded onto the trip. The vehicle load and tracking history are updated.", "ok")
        except Error as err:
            conn.rollback()
            if err.errno == 1062:
                reason = "That shipment is already loaded on this trip"
            else:
                reason = db_message(err).rstrip(".")
            flash(f"{reason}. Nothing was saved.", "error")
        finally:
            conn.close()
        return redirect(url_for("assign"))

    trips = query(
        """SELECT t.trip_id, t.status, d.name AS driver, v.plate_no, v.type,
                  v.current_load_kg, v.capacity_kg, fh.city AS from_city, th.city AS to_city
           FROM Trip t
           JOIN Driver d ON d.driver_id = t.driver_id
           JOIN Vehicle v ON v.vehicle_id = t.vehicle_id
           JOIN Hub fh ON fh.hub_id = t.from_hub_id
           JOIN Hub th ON th.hub_id = t.to_hub_id
           WHERE t.status IN ('Planned','Ongoing') ORDER BY t.trip_id DESC""")
    shipments = query(
        """SELECT s.shipment_id, s.tracking_number, s.weight_kg, s.current_status,
                  hs.city AS from_city, hd.city AS to_city
           FROM Shipment s JOIN Hub hs ON hs.hub_id = s.source_hub_id
                           JOIN Hub hd ON hd.hub_id = s.dest_hub_id
           WHERE s.current_status IN ('Booked','In Transit') ORDER BY s.tracking_number""")
    drivers = query("SELECT driver_id, name FROM Driver WHERE status='Active' ORDER BY name")
    vehicles = query("SELECT vehicle_id, plate_no, type, capacity_kg FROM Vehicle "
                     "WHERE status='Available' ORDER BY plate_no")
    return render_template("assign.html", trips=trips, shipments=shipments,
                           drivers=drivers, vehicles=vehicles, hubs=hubs())


@app.route("/trips/new", methods=["POST"])
def new_trip():
    f = request.form
    try:
        driver, vehicle = int(f["driver_id"]), int(f["vehicle_id"])
        src, dst = int(f["from_hub_id"]), int(f["to_hub_id"])
    except (KeyError, ValueError):
        flash("Fill in every field to plan a trip.", "error")
        return redirect(url_for("assign"))
    if src == dst:
        flash("A trip needs two different hubs.", "error")
        return redirect(url_for("assign"))
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("INSERT INTO Trip (driver_id, vehicle_id, from_hub_id, to_hub_id, "
                    "start_time, status) VALUES (%s,%s,%s,%s,NOW(),'Planned')",
                    (driver, vehicle, src, dst))
        conn.commit()
        flash(f"Trip {cur.lastrowid} planned. You can now load shipments onto it.", "ok")
    except Error as err:
        conn.rollback()
        flash(db_message(err), "error")
    finally:
        conn.close()
    return redirect(url_for("assign"))


# ---------- 4. add a tracking event (fires the trigger) ----------
@app.route("/events/new", methods=["GET", "POST"])
def new_event():
    if request.method == "POST":
        f = request.form
        try:
            sid, status = int(f["shipment_id"]), f["status"]
            hub = int(f["hub_id"]) if f.get("hub_id") else None
        except (KeyError, ValueError):
            flash("Choose a shipment and a status.", "error")
            return redirect(url_for("new_event"))
        current = query("SELECT current_status, tracking_number FROM Shipment WHERE shipment_id=%s",
                        (sid,))
        if not current or status not in STATUSES:
            flash("Unknown shipment or status.", "error")
        elif current[0]["current_status"] == "Delivered":
            flash(f"{current[0]['tracking_number']} is already delivered. "
                  "No more events can be added.", "error")
        else:
            conn = get_conn()
            try:
                cur = conn.cursor()
                cur.execute("INSERT INTO Tracking_Event (shipment_id, hub_id, status, remarks) "
                            "VALUES (%s,%s,%s,%s)", (sid, hub, status, f.get("remarks") or None))
                # Sync status in case database engine does not support triggers
                new_status = 'In Transit' if status in ('Picked Up', 'Arrived at Hub', 'Departed Hub') else status
                if status == 'Delivered':
                    cur.execute("UPDATE Shipment SET current_status=%s, delivered_date=NOW() WHERE shipment_id=%s", (new_status, sid))
                else:
                    cur.execute("UPDATE Shipment SET current_status=%s WHERE shipment_id=%s", (new_status, sid))
                conn.commit()
            except Error as err:
                conn.rollback()
                flash(db_message(err), "error")
                return redirect(url_for("new_event"))
            finally:
                conn.close()
            return redirect(url_for("track", tracking_number=current[0]["tracking_number"]))
        return redirect(url_for("new_event"))
    shipments = query("SELECT shipment_id, tracking_number, current_status FROM Shipment "
                      "WHERE current_status <> 'Delivered' ORDER BY tracking_number")
    return render_template("new_event.html", shipments=shipments, hubs=hubs(),
                           statuses=STATUSES)


# ---------- 5. reports ----------
@app.route("/reports")
def reports():
    late = query(
        """SELECT h.name AS hub, COUNT(*) AS delivered,
                  SUM(DATE(s.delivered_date) > s.expected_date) AS late,
                  ROUND(100*SUM(DATE(s.delivered_date) > s.expected_date)/COUNT(*),1) AS late_pct
           FROM Shipment s JOIN Hub h ON h.hub_id = s.dest_hub_id
           WHERE s.current_status='Delivered' GROUP BY h.hub_id, h.name ORDER BY late DESC""")
    drivers = query(
        """SELECT d.name AS driver, COUNT(DISTINCT t.trip_id) AS trips,
                  COUNT(DISTINCT CASE WHEN s.current_status='Delivered' THEN s.shipment_id END) AS delivered
           FROM Driver d LEFT JOIN Trip t ON t.driver_id = d.driver_id
                         LEFT JOIN Trip_Shipment ts ON ts.trip_id = t.trip_id
                         LEFT JOIN Shipment s ON s.shipment_id = ts.shipment_id
           GROUP BY d.driver_id, d.name ORDER BY delivered DESC, trips DESC""")
    service = query("SELECT service_type, COUNT(*) AS shipments, SUM(cost) AS revenue "
                    "FROM Shipment GROUP BY service_type ORDER BY revenue DESC")
    city = query("SELECT h.city, COUNT(*) AS shipments, SUM(s.cost) AS revenue "
                 "FROM Shipment s JOIN Hub h ON h.hub_id = s.source_hub_id "
                 "GROUP BY h.city ORDER BY revenue DESC")
    vehicles = query("SELECT plate_no, type, status, current_load_kg, capacity_kg, "
                     "ROUND(100*current_load_kg/capacity_kg,1) AS pct FROM Vehicle ORDER BY pct DESC")
    failed = query("SELECT c.name, c.city, COUNT(*) AS failed FROM Shipment s "
                   "JOIN Customer c ON c.customer_id = s.sender_id "
                   "WHERE s.current_status='Failed' GROUP BY c.customer_id, c.name, c.city "
                   "ORDER BY failed DESC")
    return render_template("reports.html", late=late, drivers=drivers, service=service,
                           city=city, vehicles=vehicles, failed=failed)


# ---------- 6. add master records (customer, driver, vehicle, hub) ----------
def add_record(sql, params, what):
    """INSERT one master record and tell the user the result."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        conn.commit()
        flash(f"{what} added (id {cur.lastrowid}).", "ok")
        return True
    except Error as err:
        conn.rollback()
        flash(db_message(err), "error")
        return False
    finally:
        conn.close()


def clean(form, name):
    return (form.get(name) or "").strip()


@app.route("/add")
def add_records():
    counts = query("SELECT (SELECT COUNT(*) FROM Customer) AS customers, "
                   "(SELECT COUNT(*) FROM Driver) AS drivers, "
                   "(SELECT COUNT(*) FROM Vehicle) AS vehicles, "
                   "(SELECT COUNT(*) FROM Hub) AS hubs")[0]
    return render_template("add_records.html", hubs=hubs(), counts=counts)


@app.route("/add/customer", methods=["POST"])
def add_customer():
    f = request.form
    name, phone, email = clean(f, "name"), clean(f, "phone"), clean(f, "email")
    address, city, pincode = clean(f, "address"), clean(f, "city"), clean(f, "pincode")
    if not (name and phone and address and city and pincode):
        flash("Name, phone, address, city and pincode are required.", "error")
    elif not re.fullmatch(r"\d{7,15}", phone):
        flash("Phone must contain only digits (7 to 15 of them).", "error")
    elif not re.fullmatch(r"\d{6}", pincode):
        flash("Pincode must be exactly 6 digits.", "error")
    elif email and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        flash("That email address does not look valid.", "error")
    else:
        add_record("INSERT INTO Customer (name, phone, email, address, city, pincode) "
                   "VALUES (%s,%s,%s,%s,%s,%s)",
                   (name, phone, email or None, address, city, pincode), "Customer")
    return redirect(url_for("add_records"))


@app.route("/add/driver", methods=["POST"])
def add_driver():
    f = request.form
    name, phone, lic = clean(f, "name"), clean(f, "phone"), clean(f, "license_no")
    if not (name and phone and lic and f.get("hub_id")):
        flash("Name, phone, licence number and home hub are required.", "error")
    elif not re.fullmatch(r"\d{7,15}", phone):
        flash("Phone must contain only digits (7 to 15 of them).", "error")
    else:
        add_record("INSERT INTO Driver (name, phone, license_no, hub_id) VALUES (%s,%s,%s,%s)",
                   (name, phone, lic, int(f["hub_id"])), "Driver")
    return redirect(url_for("add_records"))


@app.route("/add/vehicle", methods=["POST"])
def add_vehicle():
    f = request.form
    plate, vtype = clean(f, "plate_no").upper(), f.get("type")
    try:
        cap = float(f.get("capacity_kg", ""))
    except ValueError:
        cap = 0
    if not (plate and f.get("hub_id")) or vtype not in ("Bike", "Van", "Truck"):
        flash("Plate number, type and home hub are required.", "error")
    elif cap <= 0:
        flash("Capacity must be a number above 0.", "error")
    else:
        add_record("INSERT INTO Vehicle (plate_no, type, capacity_kg, hub_id) VALUES (%s,%s,%s,%s)",
                   (plate, vtype, cap, int(f["hub_id"])), "Vehicle")
    return redirect(url_for("add_records"))


@app.route("/add/hub", methods=["POST"])
def add_hub():
    f = request.form
    name, city = clean(f, "name"), clean(f, "city")
    try:
        cap = int(f.get("capacity", ""))
    except ValueError:
        cap = 0
    if not (name and city):
        flash("Hub name and city are required.", "error")
    elif cap <= 0:
        flash("Capacity must be a whole number above 0.", "error")
    else:
        add_record("INSERT INTO Hub (name, city, capacity) VALUES (%s,%s,%s)",
                   (name, city, cap), "Hub")
    return redirect(url_for("add_records"))


if __name__ == "__main__":
    app.run(debug=True)
